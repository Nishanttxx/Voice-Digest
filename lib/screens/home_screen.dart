import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:voice_digest/screens/result_screen.dart';
import 'package:voice_digest/services/isar_service.dart';

class HomeScreen extends StatefulWidget {
  final IsarService isarService;
  const HomeScreen({super.key, required this.isarService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _sourceLanguage = 'English';
  String _targetLanguage = 'Spanish';
  bool _isRecording = false;

  final AudioRecorder _audioRecorder = AudioRecorder();

  final List<String> _languages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
  ];

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _handleRecordingTap() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (!mounted) return;

        setState(() {
          _isRecording = false;
        });

        final recordedPath = path;
        if (recordedPath == null || recordedPath.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed to save.')),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              audioPath: recordedPath,
              sourceLanguage: _sourceLanguage,
              targetLanguage: _targetLanguage,
              isarService: widget.isarService,
            ),
          ),
        );
        return;
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
        return;
      }

      String? filePath;
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filePath = '${dir.path}/recording_$timestamp.wav';
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
        ),
        path: filePath ?? 'recording.wav',
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording error: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Voice Digest'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Language Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLanguageDropdown('From', _sourceLanguage, (val) {
                  setState(() => _sourceLanguage = val!);
                }),
                const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
                _buildLanguageDropdown('To', _targetLanguage, (val) {
                  setState(() => _targetLanguage = val!);
                }),
              ],
            ),
            // Recording Button and Status (now only for UI display)
            Column(
              children: [
                _buildRecordButton(),
                const SizedBox(height: 20),
                if (_isRecording)
                  const Text(
                    'Listening...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 1.seconds).then().fadeOut(duration: 1.seconds),
              ],
            ),
            // Spacer
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(
      String label, String value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
              onChanged: onChanged,
              items: _languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    final button = GestureDetector(
      onTap: _handleRecordingTap, // Now calls the disabled handler
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.withOpacity(0.6),
              Colors.purpleAccent.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 15,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 80,
          ),
        ),
      ),
    );

    // Animation is now purely decorative as _isRecording is false
    if (_isRecording) {
      return button
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.1, 1.1),
            duration: 1.seconds,
            curve: Curves.easeInOut,
          );
    } else {
      return button;
    }
  }
}
