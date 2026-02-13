import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_digest/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable or disable the dark theme'),
              value: themeMode == ThemeMode.dark,
              onChanged: (bool value) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
              secondary: Icon(
                themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
            // Add other settings here as needed
          ],
        ),
      ),
    );
  }
}
