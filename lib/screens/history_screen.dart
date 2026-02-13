import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:voice_digest/models/voice_digest.dart';
import 'package:voice_digest/services/isar_service.dart';

class HistoryScreen extends StatefulWidget {
  final IsarService isarService;

  const HistoryScreen({super.key, required this.isarService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<VoiceDigest>> _digestsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDigests();
  }

  void _refreshDigests() {
    setState(() {
      _digestsFuture = widget.isarService.getAllDigests();
    });
  }

  void _deleteDigest(int id) async {
    await widget.isarService.deleteDigest(id);
    _refreshDigests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<VoiceDigest>>(
        future: _digestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No digests saved yet.',
                style: TextStyle(fontSize: 18, color: Colors.white54),
              ),
            );
          } else {
            final digests = snapshot.data!;
            return ListView.builder(
              itemCount: digests.length,
              itemBuilder: (context, index) {
                final digest = digests[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            digest.originalTranscript.split('\n').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            "${digest.sourceLanguage} to ${digest.targetLanguage}\n${digest.createdAt.toLocal().toString().split(' ').first}",
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteDigest(digest.id),
                          ),
                          onTap: () {
                            // TODO: Navigate to a detail view of the digest
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
