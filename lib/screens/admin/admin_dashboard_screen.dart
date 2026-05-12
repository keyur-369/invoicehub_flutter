import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildAdminCard(context, Icons.category, 'Categories', Colors.orange, () {}),
          _buildAdminCard(context, Icons.branding_watermark, 'Brands', Colors.blue, () {}),
          _buildAdminCard(context, Icons.inventory, 'Master Products', Colors.green, () {}),
          _buildAdminCard(context, Icons.store, 'Shops', Colors.purple, () {}),
          _buildAdminCard(context, Icons.subscriptions, 'Subscriptions', Colors.red, () {}),
          _buildAdminCard(context, Icons.analytics, 'Global Reports', Colors.teal, () {}),
        ],
      ),
    );
  }
  Widget _buildAdminCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
