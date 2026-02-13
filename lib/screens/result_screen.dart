import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:voice_digest/models/voice_digest.dart';
import 'package:voice_digest/services/isar_service.dart';
import 'package:voice_digest/utils/audio_bytes.dart';

class ResultScreen extends StatefulWidget {
  final String audioPath;
  final String sourceLanguage;
  final String targetLanguage;
  final IsarService isarService;

  const ResultScreen({
    super.key,
    required this.audioPath,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.isarService,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _transcript = '';
  String _translatedText = '';
  bool _isProcessing = true;
  bool _isSaving = false;
  bool _isSaved = false;
  String _error = '';

  late final GenerativeModel _model;
  late final String _modelName;
  String? _apiVersion;
  static const String _defaultModelFallback = 'gemini-1.5-flash';
  static const List<String> _preferredModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  @override
  void initState() {
    super.initState();
    _initModelAndProcess();
  }

  Future<void> _initModelAndProcess() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _setError('Missing GEMINI_API_KEY in .env.');
      return;
    }

    _apiVersion = dotenv.env['GEMINI_API_VERSION']?.trim();
    if (_apiVersion != null && _apiVersion!.isEmpty) {
      _apiVersion = null;
    }
    try {
      _modelName = await _resolveModelName(apiKey);
    } catch (error) {
      _setError('Model discovery failed: $error');
      return;
    }

    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      requestOptions:
          _apiVersion == null ? null : RequestOptions(apiVersion: _apiVersion),
    );

    await _processAudio();
  }

  Future<void> _processAudio() async {
    final audioPath = widget.audioPath.trim();
    if (audioPath.isEmpty) {
      _setError('No audio was recorded.');
      return;
    }

    try {
      final Uint8List bytes = await readAudioBytes(audioPath);
      const maxInlineBytes = 20 * 1024 * 1024;
      if (bytes.lengthInBytes > maxInlineBytes) {
        _setError('Recording is too large for inline processing. Please record a shorter clip.');
        return;
      }
      final mimeType = _guessMimeType(audioPath);
      final prompt = _buildPrompt(
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      final response = await _model.generateContent(
        [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, bytes),
          ]),
        ],
        generationConfig: GenerationConfig(
          temperature: 0.2,
        ),
      );

      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        _setError('No response from Gemini.');
        return;
      }

      final parsed = _parseModelOutput(text);
      if (parsed == null) {
        _setError('Could not parse the Gemini response.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _transcript = parsed.transcript;
        _translatedText = parsed.translation;
        _isProcessing = false;
      });
    } catch (error) {
      final versionInfo =
          _apiVersion == null ? '' : ' (apiVersion: $_apiVersion)';
      _setError('Processing failed with model $_modelName$versionInfo: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isProcessing = false;
    });
  }

  Future<String> _resolveModelName(String apiKey) async {
    final envModel = dotenv.env['GEMINI_MODEL']?.trim();
    if (envModel != null && envModel.isNotEmpty) {
      return envModel;
    }

    final versionsToTry = <String>[
      if (_apiVersion != null) _apiVersion!,
      if (_apiVersion == null) 'v1beta',
      if (_apiVersion == null) 'v1',
    ];

    for (final version in versionsToTry) {
      try {
        final models = await _listModels(apiKey, version);
        if (models.isEmpty) {
          continue;
        }
        _apiVersion ??= version;
        for (final preferred in _preferredModels) {
          if (models.contains(preferred)) {
            return preferred;
          }
        }
        final geminiModel = models.firstWhere(
          (m) => m.startsWith('gemini-'),
          orElse: () => models.first,
        );
        return geminiModel;
      } catch (_) {
        if (_apiVersion != null) {
          rethrow;
        }
      }
    }

    return _defaultModelFallback;
  }

  Future<List<String>> _listModels(String apiKey, String apiVersion) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/$apiVersion/models',
      {'pageSize': '1000'},
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.add('x-goog-api-key', apiKey);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('ListModels failed with status ${response.statusCode}.');
      }

      final decoded = jsonDecode(body);
      final models = (decoded['models'] as List?) ?? const [];
      final results = <String>[];
      for (final model in models) {
        if (model is! Map) continue;
        final name = model['name'];
        final methods = model['supportedGenerationMethods'];
        if (name is! String || methods is! List) continue;
        final supportsGenerate =
            methods.whereType<String>().contains('generateContent');
        if (!supportsGenerate) continue;
        if (name.startsWith('models/')) {
          results.add(name.substring('models/'.length));
        } else {
          results.add(name);
        }
      }
      return results;
    } finally {
      client.close(force: true);
    }
  }

  String _buildPrompt({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return '''
You are a transcription and translation engine.
Transcribe the speech in the audio. The expected source language is "$sourceLanguage".
Translate the transcript into "$targetLanguage". If the languages are the same, return the original text.

Return ONLY valid JSON with exactly these keys:
{"transcript":"...", "translation":"..."}
No Markdown or extra text.
''';
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/m4a';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/wav';
  }

  _GeminiParseResult? _parseModelOutput(String text) {
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      final jsonText = jsonMatch.group(0)!;
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map) {
          final transcript = (decoded['transcript'] ?? '').toString().trim();
          final translation = (decoded['translation'] ?? '').toString().trim();
          if (transcript.isNotEmpty || translation.isNotEmpty) {
            return _GeminiParseResult(
              transcript: transcript,
              translation: translation.isEmpty ? transcript : translation,
            );
          }
        }
      } catch (_) {}
    }

    final transcript = _extractSection(cleaned, 'transcript');
    final translation = _extractSection(cleaned, 'translation');
    if (transcript != null && transcript.isNotEmpty) {
      return _GeminiParseResult(
        transcript: transcript,
        translation: translation?.isNotEmpty == true ? translation! : transcript,
      );
    }
    return null;
  }

  String? _extractSection(String text, String label) {
    final pattern = RegExp(
      '$label\\s*:\\s*([\\s\\S]*?)(?:\\n\\s*\\w+\\s*:|\\\$)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }

  Future<void> _saveDigest() async {
    if (_isSaving || _transcript.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final newDigest = VoiceDigest()
      ..originalTranscript = _transcript
      ..translatedText = _translatedText
      ..sourceLanguage = widget.sourceLanguage
      ..targetLanguage = widget.targetLanguage
      ..createdAt = DateTime.now();

    await widget.isarService.saveDigest(newDigest);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Digest saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Your Voice Digest'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Generating digest...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection('Original Transcript', _transcript),
                      const SizedBox(height: 30),
                      _buildSection('Translated Text', _translatedText),
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurpleAccent,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: "$_transcript\n\n$_translatedText"));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard!')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: () {
            // TODO: Implement share functionality
          },
        ),
        IconButton(
          icon: Icon(_isSaved ? Icons.check : Icons.save),
          tooltip: _isSaved ? 'Saved' : 'Save',
          onPressed: _isSaved ? null : _saveDigest,
        ),
      ],
    );
  }
}

class _GeminiParseResult {
  final String transcript;
  final String translation;

  const _GeminiParseResult({
    required this.transcript,
    required this.translation,
  });
}
