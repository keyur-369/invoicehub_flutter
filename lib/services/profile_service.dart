import 'dart:io';
import 'package:invoicehub/core/constants/constants.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:invoicehub/services/supabase_service.dart';

class ProfileService extends SupabaseService {
  Future<Profile?> getProfile(String userId) async {
    final response = await client
        .from(DatabaseTables.profiles)
        .select()
        .eq('user_id', userId)
        .single();
    
    return Profile.fromJson(response);
  }

  Future<void> upsertProfile(Profile profile) async {
    final data = profile.toJson();
    if (profile.id.isEmpty) {
      data.remove('id'); // Let Supabase generate a new UUID
    }
    await client
        .from(DatabaseTables.profiles)
        .upsert(data);
  }

  Future<String> uploadLogo(String profileId, File file) async {
    final fileName = 'logo_$profileId.${file.path.split('.').last}';
    final path = await storage.from(AppConstants.logosBucket).upload(
          fileName,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    
    return storage.from(AppConstants.logosBucket).getPublicUrl(fileName);
  }

  Future<List<Profile>> getAllShops() async {
    final response = await client
        .from(DatabaseTables.profiles)
        .select()
        .eq('role', 'shop_owner')
        .order('shop_name');
    
    return (response as List).map((p) => Profile.fromJson(p)).toList();
  }
}
