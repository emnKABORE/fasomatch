import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityService {
  final supabase = Supabase.instance.client;

  Future<void> blockUser(String blockedUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('user_blocks').upsert({
      'blocker_id': user.id,
      'blocked_id': blockedUserId,
    });
  }

  Future<void> unblockUser(String blockedUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('user_blocks')
        .delete()
        .eq('blocker_id', user.id)
        .eq('blocked_id', blockedUserId);
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('reports').insert({
      'reporter_id': user.id,
      'reported_id': reportedUserId,
      'reason': reason,
      'details': details,
    });
  }
}