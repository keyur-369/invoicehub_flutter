import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  GoTrueClient get auth => client.auth;
  SupabaseStorageClient get storage => client.storage;
}
