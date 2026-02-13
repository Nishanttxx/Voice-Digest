import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Isar imports are no longer needed as database setup is removed from test
// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:isar/isar.dart';

import 'package:voice_digest/main.dart';
import 'package:voice_digest/services/isar_service.dart';

void main() {
  // No more setUpAll for Isar and path_provider needed as recording/saving removed
  // setUpAll(() async {
  //   TestWidgetsFlutterBinding.ensureInitialized();
  //   await Isar.initializeIsarCore(download: true);

  //   final dir = await Directory.systemTemp.createTemp();

  //   const MethodChannel('plugins.flutter.io/path_provider')
  //       .setMockMethodCallHandler((MethodCall methodCall) async {
  //     if (methodCall.method == 'getApplicationDocumentsDirectory') {
  //       return dir.path;
  //     }
  //     return null;
  //   });
  // });

  testWidgets('App starts and shows the home screen', (WidgetTester tester) async {
    // Create a mock instance of IsarService since real one is no longer needed for tests
    final isarService = IsarService(); // We can still instantiate, but it won't open a real DB

    // No need to wait for isarService.db as it's not being opened in tests anymore

    // Build our app and trigger a frame.
    await tester.pumpWidget(ProviderScope(
      child: VoiceDigestApp(isarService: isarService),
    ));

    // Wait for all widgets and animations to settle.
    await tester.pumpAndSettle();

    // Verify that the main UI elements of the home screen are present.
    expect(find.text('Voice Digest'), findsOneWidget); // AppBar title
    expect(find.byIcon(Icons.mic), findsOneWidget);      // Record button
    expect(find.byIcon(Icons.history), findsOneWidget); // Bottom nav icon
  });
}
