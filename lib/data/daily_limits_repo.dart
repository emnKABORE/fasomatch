import 'package:supabase_flutter/supabase_flutter.dart';

/// Actions soumises à limites quotidiennes
enum LimitAction { swipe, superlike, rewind }

class LimitResult {
  final bool ok;
  final LimitAction action;

  /// compte utilisé/limite pour l'action demandée
  final int used;
  final int limit;

  /// optionnel: détails swipes si ton RPC renvoie aussi swipes_used/swipes_limit
  final int? swipesUsed;
  final int? swipesLimit;

  /// message erreur optionnel
  final String? error;

  const LimitResult({
    required this.ok,
    required this.action,
    required this.used,
    required this.limit,
    this.swipesUsed,
    this.swipesLimit,
    this.error,
  });
}

class DailyLimitsRepo {
  DailyLimitsRepo(this._supabase);
  final SupabaseClient _supabase;

  String _actionToRpc(LimitAction a) {
    switch (a) {
      case LimitAction.swipe:
        return 'swipe';
      case LimitAction.superlike:
        return 'superlike';
      case LimitAction.rewind:
        return 'rewind';
    }
  }

  LimitAction _actionFromRpc(String s) {
    switch (s) {
      case 'swipe':
        return LimitAction.swipe;
      case 'superlike':
        return LimitAction.superlike;
      case 'rewind':
        return LimitAction.rewind;
      default:
        return LimitAction.swipe;
    }
  }

  /// ✅ ATOMIQUE : toute la logique est côté DB (RPC)
  /// plan attendu: 'free' | 'premium' | 'ultra'
  Future<LimitResult> consumeAction({
    required String userId,
    required String plan,
    required LimitAction action,
  }) async {
    final payload = await _supabase.rpc(
      'consume_actions',
      params: {
        'p_user_id': userId,
        'p_plan': plan,
        'p_action': _actionToRpc(action),
      },
    );

    // payload attendu (exemples):
    // { ok: true, action: "swipe", used: 3, limit: 20 }
    // { ok: false, action: "superlike", used: 1, limit: 1, error: "limit_reached", swipes_used: 19, swipes_limit: 20 }

    final m = Map<String, dynamic>.from(payload as Map);

    final ok = (m['ok'] == true);
    final act = _actionFromRpc((m['action'] ?? _actionToRpc(action)).toString());

    // selon ton RPC, le champ peut s'appeler "used" ou "superlikes_used" etc.
    // on gère les deux cas :
    int used = 0;
    int limit = 0;

    if (m.containsKey('used')) used = (m['used'] ?? 0) as int;
    if (m.containsKey('limit')) limit = (m['limit'] ?? 0) as int;

    // fallback si ton RPC renvoie "superlikes_used"/"superlikes_limit" etc.
    if (act == LimitAction.superlike) {
      used = (m['used'] ?? m['superlikes_used'] ?? 0) as int;
      limit = (m['limit'] ?? m['superlikes_limit'] ?? 0) as int;
    }
    if (act == LimitAction.swipe) {
      used = (m['used'] ?? m['swipes_used'] ?? 0) as int;
      limit = (m['limit'] ?? m['swipes_limit'] ?? 0) as int;
    }
    if (act == LimitAction.rewind) {
      used = (m['used'] ?? m['rewind_used'] ?? 0) as int;
      limit = (m['limit'] ?? m['rewind_limit'] ?? 0) as int;
    }

    return LimitResult(
      ok: ok,
      action: act,
      used: used,
      limit: limit,
      swipesUsed: (m['swipes_used'] as int?),
      swipesLimit: (m['swipes_limit'] as int?),
      error: m['error']?.toString(),
    );
  }
}