import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/services/profile_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManageShopsScreen extends ConsumerWidget {
  const ManageShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Registered Shops')),
      body: FutureBuilder<List<Profile>>(
        future: ref.read(profileServiceProvider).getAllShops(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final shops = snapshot.data ?? [];
          
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.blue.withOpacity(0.1),
                child: Column(
                  children: [
                    const Text('Total Registered Owners', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('${shops.length}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
              Expanded(
                child: shops.isEmpty 
                  ? const Center(child: Text('No shops registered yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: shops.length,
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: shop.logoUrl != null ? CachedNetworkImageProvider(shop.logoUrl!) : null,
                              child: shop.logoUrl == null ? const Icon(Icons.store) : null,
                            ),
                            title: Text(shop.shopName ?? 'Unnamed Shop', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Owner: ${shop.ownerName ?? 'N/A'}'),
                                Text('Mobile: ${shop.mobile ?? 'N/A'}'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _showShopDetails(context, shop);
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShopDetails(BuildContext context, Profile shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: shop.logoUrl != null
                    ? CachedNetworkImage(imageUrl: shop.logoUrl!, height: 100, width: 100, fit: BoxFit.contain)
                    : const Icon(Icons.store, size: 80),
              ),
              const SizedBox(height: 24),
              _detailRow('Shop Name', shop.shopName),
              _detailRow('Owner Name', shop.ownerName),
              _detailRow('GST Number', shop.gstNumber),
              _detailRow('Mobile', shop.mobile),
              _detailRow('Email', shop.email),
              _detailRow('City', shop.city),
              _detailRow('Address', shop.address),
              const SizedBox(height: 20),
              Center(
                child: Text('Joined on ${shop.createdAt?.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value ?? 'N/A', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Divider(),
        ],
      ),
    );
  }
}
