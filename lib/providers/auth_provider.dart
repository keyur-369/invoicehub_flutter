import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/services/auth_service.dart';
import 'package:invoicehub/services/profile_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final profileServiceProvider = Provider((ref) => ProfileService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<Profile?>>((ref) {
  return ProfileNotifier(ref);
});

class ProfileNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final Ref _ref;
  ProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen(authStateProvider, (previous, next) {
      final user = next.value?.session?.user;
      if (user != null) {
        fetchProfile(user.id);
      } else {
        state = const AsyncValue.data(null);
      }
    });
  }

  Future<void> fetchProfile(String userId) async {
    try {
      final profile = await _ref.read(profileServiceProvider).getProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      // If profile doesn't exist, we just set it to null so router can handle it
      state = const AsyncValue.data(null);
    }
  }

  Future<void> saveProfile(Profile profile) async {
    try {
      await _ref.read(profileServiceProvider).upsertProfile(profile);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
