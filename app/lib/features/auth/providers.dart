import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/app_env.dart';
import 'data/supabase_auth_repository.dart';
import 'data/unconfigured_auth_repository.dart';
import 'domain/auth_repository.dart';
import 'domain/auth_user.dart';

/// Supabase client — only valid when [AppEnv.isSupabaseConfigured].
final supabaseClientProvider = Provider<sb.SupabaseClient>((ref) {
  assert(AppEnv.isSupabaseConfigured, 'Supabase is not configured');
  return sb.Supabase.instance.client;
});

/// The active [AuthRepository]. Tests override this with fakes.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) return const UnconfiguredAuthRepository();
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Reactive auth state for widgets (null = signed out).
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Synchronous snapshot of the current user.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final async = ref.watch(authStateProvider);
  return async.value ?? ref.watch(authRepositoryProvider).currentUser;
});
