import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:invoicehub/services/supabase_service.dart';

class AuthService extends SupabaseService {
  User? get currentUser => auth.currentUser;
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await auth.resetPasswordForEmail(email);
  }
}
