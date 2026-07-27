import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            currentAccountPicture: CircleAvatar(
              backgroundImage: profile?.logoUrl != null ? NetworkImage(profile!.logoUrl!) : null,
              child: profile?.logoUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            accountName: Text(profile?.shopName ?? 'Shop Name'),
            accountEmail: Text(profile?.email ?? 'Email'),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Edit Business Profile'),
            onTap: () => context.push('/complete-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Security'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
