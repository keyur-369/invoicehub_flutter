import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/providers/customer_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final customersAsync = ref.watch(customersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        elevation: 0,
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No customers found. Add one!', 
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      customer.customerName[0].toUpperCase(),
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    customer.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (customer.mobile != null && customer.mobile!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(customer.mobile!),
                            ],
                          ),
                        ),
                      if (customer.city != null && customer.city!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(customer.city!),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showCustomerDialog(context, ref, profile!.id, customer: customer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(context, ref, customer),
                      ),
                    ],
                  ),
                  onTap: () => _showCustomerDialog(context, ref, profile!.id, customer: customer),
                ),
              );
              },
            );
          },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(context, ref, profile!.id),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${customer.customerName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(businessRepoProvider).deleteCustomer(customer.id);
              ref.invalidate(customersProvider);
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer deleted successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref, String shopId, {Customer? customer}) {
    final nameController = TextEditingController(text: customer?.customerName);
    final mobileController = TextEditingController(text: customer?.mobile);
    final cityController = TextEditingController(text: customer?.city);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(customer == null ? 'Add New Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController, 
                decoration: const InputDecoration(
                  labelText: 'Customer Name*', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController, 
                decoration: const InputDecoration(
                  labelText: 'Mobile Number', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController, 
                decoration: const InputDecoration(
                  labelText: 'City', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              final newCustomer = Customer(
                id: customer?.id ?? '',
                shopId: shopId,
                customerName: nameController.text.trim(),
                mobile: mobileController.text.trim(),
                city: cityController.text.trim(),
                createdAt: customer?.createdAt ?? DateTime.now(),
              );
              
              try {
                if (customer == null) {
                  await ref.read(businessRepoProvider).addCustomer(newCustomer);
                } else {
                  await ref.read(businessRepoProvider).updateCustomer(newCustomer);
                }
                
                ref.invalidate(customersProvider);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(customer == null ? 'Customer added' : 'Customer updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
