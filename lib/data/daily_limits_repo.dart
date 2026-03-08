import 'package:supabase_flutter/supabase_flutter.dart';

/// Actions soumises à limites quotidiennes
enum LimitAction { swipe, superlike, rewind }

class LimitResult {
  final bool ok;
  final LimitAction action;

  /// compte utilisé/limite pour l'action demandée
  final int used;
  final int limit;

  /// optionnel: détails swipes si la RPC renvoie aussi swipes_used/swipes_limit
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

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw Exception("RPC payload not a map: $payload");
  }

  /// ✅ ATOMIQUE (1 action) : toute la logique est côté DB
  /// plan attendu: 'free' | 'premium' | 'ultra'
  ///
  /// IMPORTANT: d'après tes RPC, la fonction s'appelle `consume_action`
  /// et les params sont: p_uid, p_plan, p_action
  Future<LimitResult> consumeAction({
    required String userId,
    required String plan,
    required LimitAction action,
  }) async {
    final payload = await _supabase.rpc(
      'consume_action',
      params: {
        'p_uid': userId,
        'p_plan': plan,
        'p_action': _actionToRpc(action),
      },
    );

    final m = _asMap(payload);

    final ok = (m['ok'] == true);
    final act = _actionFromRpc((m['action'] ?? _actionToRpc(action)).toString());

    // champs possibles selon ton SQL: used/limit ou swipes_used/... etc.
    int used = _asInt(m['used']);
    int limit = _asInt(m['limit']);

    if (act == LimitAction.swipe) {
      used = _asInt(m['used'] ?? m['swipes_used']);
      limit = _asInt(m['limit'] ?? m['swipes_limit']);
    } else if (act == LimitAction.superlike) {
      used = _asInt(m['used'] ?? m['superlikes_used']);
      limit = _asInt(m['limit'] ?? m['superlikes_limit']);
    } else if (act == LimitAction.rewind) {
      used = _asInt(m['used'] ?? m['rewind_used']);
      limit = _asInt(m['limit'] ?? m['rewind_limit']);
    }

    return LimitResult(
      ok: ok,
      action: act,
      used: used,
      limit: limit,
      swipesUsed: m.containsKey('swipes_used') ? _asInt(m['swipes_used']) : null,
      swipesLimit: m.containsKey('swipes_limit') ? _asInt(m['swipes_limit']) : null,
      error: m['error']?.toString(),
    );
  }

  /// ✅ ATOMIQUE (SuperLike + Swipe ensemble) :
  /// utilise ta RPC `consume_superlike_and_swipe(p_uid uuid, p_plan text)`
  Future<LimitResult> consumeSuperlikeAndSwipe({
    required String userId,
    required String plan,
  }) async {
    final payload = await _supabase.rpc(
      'consume_superlike_and_swipe',
      params: {
        'p_uid': userId,
        'p_plan': plan,
      },
    );

    final m = _asMap(payload);

    final ok = (m['ok'] == true);

    // cette RPC peut renvoyer action="superlike" ou "superlike_and_swipe"
    // on force l'action côté app = superlike (car c'est le bouton)
    int used = _asInt(m['used'] ?? m['superlikes_used']);
    int limit = _asInt(m['limit'] ?? m['superlikes_limit']);

    return LimitResult(
      ok: ok,
      action: LimitAction.superlike,
      used: used,
      limit: limit,
      swipesUsed: m.containsKey('swipes_used') ? _asInt(m['swipes_used']) : null,
      swipesLimit: m.containsKey('swipes_limit') ? _asInt(m['swipes_limit']) : null,
      error: m['error']?.toString(),
    );
  }
}