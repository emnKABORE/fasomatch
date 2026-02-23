import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_card.dart';

class SwipeService {
  final SupabaseClient supabase;
  SwipeService(this.supabase);

  String get currentUserId => supabase.auth.currentUser!.id;

  Future<List<ProfileCardData>> getCandidates({
    String? city,
    int? ageMin,
    int? ageMax,
    int limit = 20,
  }) async {
    final res = await supabase.rpc('get_candidates', params: {
      'p_user_id': currentUserId,
      'p_city': (city != null && city.trim().isNotEmpty) ? city.trim() : null,
      'p_age_min': ageMin,
      'p_age_max': ageMax,
      'p_limit': limit,
    });

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(ProfileCardData.fromRpc).toList();
  }

  Future<void> insertSwipe({
    required String targetId,
    required String action, // pass / like / superlike
  }) async {
    await supabase.from('swipes').insert({
      'swiper_id': currentUserId,
      'target_id': targetId,
      'action': action,
    });
  }

  /// Si je like/superlike quelqu’un, on vérifie s’il a déjà like/superlike moi
  /// sur les 28 derniers jours. Si oui => match.
  Future<bool> tryCreateMatchIfReciprocal(String targetId) async {
    final rows = await supabase
        .from('swipes')
        .select('id, action, created_at')
        .eq('swiper_id', targetId)
        .eq('target_id', currentUserId)
        .inFilter('action', ['like', 'superlike'])
        .order('created_at', ascending: false)
        .limit(1);

    if (rows is List && rows.isNotEmpty) {
      // Créer match (anti doublon géré par index unique)
      await supabase.from('matches').insert({
        'user1_id': currentUserId,
        'user2_id': targetId,
      });
      return true;
    }
    return false;
  }
}