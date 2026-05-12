import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/invoice_model.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/screens/invoice/create_invoice_screen.dart';

final invoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  final repo = ref.watch(businessRepoProvider);
  final profile = ref.watch(profileProvider).value;
  
  if (profile == null) return [];
  
  return repo.getInvoices(profile.id);
});
