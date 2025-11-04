import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Privacy & Data'),
            subtitle: Text('Local-first by default'),
          ),
          SwitchListTile(
            title: const Text('Local Only Mode'),
            subtitle: const Text('Process everything on device'),
            value: true,
            onChanged: (value) {
              // TODO: Implement toggle
            },
          ),
          SwitchListTile(
            title: const Text('Use Cloud AI'),
            subtitle: const Text('Better summaries and tags'),
            value: false,
            onChanged: (value) {
              // TODO: Implement toggle
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Model Settings'),
          ),
          ListTile(
            title: const Text('STT Model'),
            subtitle: const Text('Parakeet Tiny'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Model selection
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Account'),
          ),
          ListTile(
            title: const Text('Supabase Login'),
            subtitle: const Text('Not connected'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Login flow
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('About'),
            subtitle: Text('Parakeet Notes v0.1.0'),
          ),
        ],
      ),
    );
  }
}
