import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../settings/privacy_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    _nameController.text = _nameController.text.isEmpty ? (profile?.displayName ?? '') : _nameController.text;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.teal,
              child: Text(
                profile?.initial ?? '?',
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _editing
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Display name'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.teal),
                      onPressed: () async {
                        await auth.updateDisplayName(_nameController.text.trim());
                        setState(() => _editing = false);
                      },
                    ),
                  ],
                )
              : ListTile(
                  title: Text(profile?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(profile?.email ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _editing = true),
                  ),
                ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text('Are you sure you want to log out of your account?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('User Details', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          _detailTile('User ID', profile?.uid ?? 'Unknown'),
          _detailTile('Status', profile?.status ?? 'Offline'),
          _detailTile('Read Receipts', (profile?.showReadReceipts ?? true) ? 'Enabled' : 'Disabled'),
          _detailTile('Last Seen Visibility', (profile?.showLastSeen ?? true) ? 'Visible' : 'Hidden'),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
    );
  }
}
