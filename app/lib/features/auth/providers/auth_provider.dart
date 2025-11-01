import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth state provider (listens to Supabase auth changes)
final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((data) => data.session?.user);
});

/// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser;
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// Authentication service
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Signing in user: $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        AppLogger.info('Sign in successful: ${response.user!.id}');
      }

      return response;
    } catch (e, stack) {
      AppLogger.error('Sign in failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      AppLogger.info('Signing up user: $email');
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
        },
      );

      if (response.user != null) {
        AppLogger.info('Sign up successful: ${response.user!.id}');

        // Create user profile in users table
        await _client.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'display_name': displayName,
        });
      }

      return response;
    } catch (e, stack) {
      AppLogger.error('Sign up failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out user');
      await _client.auth.signOut();
      AppLogger.info('Sign out successful');
    } catch (e, stack) {
      AppLogger.error('Sign out failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      AppLogger.info('Sending password reset email: $email');
      await _client.auth.resetPasswordForEmail(email);
      AppLogger.info('Password reset email sent');
    } catch (e, stack) {
      AppLogger.error('Password reset failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
}

/// User profile provider (extended data from users table)
final userProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  } catch (e, stack) {
    AppLogger.error('Failed to fetch user profile', error: e, stackTrace: stack);
    return null;
  }
});

/// User venues provider (venues the user is assigned to)
final userVenuesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return [];

  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('user_venue_roles')
        .select('venue:venues(id, name, address, timezone)')
        .eq('user_id', authState.id);

    // Extract venues from the nested response
    return (response as List).map((item) {
      return item['venue'] as Map<String, dynamic>;
    }).toList();
  } catch (e, stack) {
    AppLogger.error('Failed to fetch user venues', error: e, stackTrace: stack);
    return [];
  }
});

/// User permissions provider for a specific venue
final userPermissionsProvider = FutureProvider.family<List<String>, String>((ref, venueId) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return [];

  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client.rpc('user_has_permission', params: {
      'p_user_id': authState.id,
      'p_venue_id': venueId,
    });

    return List<String>.from(response ?? []);
  } catch (e, stack) {
    AppLogger.error('Failed to fetch user permissions', error: e, stackTrace: stack);
    return [];
  }
});
