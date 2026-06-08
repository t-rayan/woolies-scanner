import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// A simple provider that exposes the current active Supabase Session.
/// If nobody is logged in, it returns null.
final authSessionProvider = Provider<Session?>((ref) {
  return SupabaseService.instance.client.auth.currentSession;
});

/// A quick boolean utility provider to easily check if the user is an admin.
final isAdminProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider);
  return session != null;
});
