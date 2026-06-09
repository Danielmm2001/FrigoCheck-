import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_constants.dart';

class AuthService {
  const AuthService();

  bool get isConfigured => ApiConstants.hasSupabaseConfig;

  SupabaseClient? get _client {
    if (!isConfigured) return null;
    return Supabase.instance.client;
  }

  User? get currentUser => _client?.auth.currentUser;

  String get currentUserId => currentUser?.id ?? ApiConstants.demoUserId;

  String? get accessToken => _client?.auth.currentSession?.accessToken;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }
}
