import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../discreet/discreet_mode_screen.dart';
import '../likes/likes_received_screen.dart';
import '../match/matches_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';

enum LimitAction { swipe, superlike, rewind }

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String currentPlan = "free";

  String? _cityFilter;
  String _bioKeyword = "";
  String? _searchTypeFilter;
  int _ageMin = 18;
  int _ageMax = 50;

  int unreadLikes = 0;
  int unreadMatches = 0;

  _UserCardData? _lastMatchedUser;

  bool _busySwipe = false;
  bool _busySuperlike = false;
  bool _busyRewind = false;

  bool _loadingProfiles = true;
  List<_UserCardData> _allUsers = [];

  String? _myGender;
  String? _myPreferredGender;
  String _myPhone = "";
  bool _myAccountHidden = false;

  Set<String> _blockedUserIds = {};
  Set<String> _blockedPhones = {};
  Set<String> _usersBlockingMe = {};

  final List<String> _cities = const [
    "Ouagadougou",
    "Bobo-Dioulasso",
    "Koudougou",
    "Banfora",
    "Ouahigouya",
    "Kaya",
    "Tenkodogo",
    "Fada N'Gourma",
    "Dédougou",
    "Gaoua",
    "Ziniaré",
    "Manga",
    "Zorgho",
    "Pouytenga",
    "Houndé",
    "Kongoussi",
    "Réo",
    "Diapaga",
    "Nouna",
    "Kombissiri",
    "Léo",
    "Gorom-Gorom",
    "Dori",
    "Sebba",
    "Bogandé",
    "Pô",
    "Boussé",
    "Tougan",
    "Yako",
    "Sindou",
  ];

  int _index = 0;
  bool _showNoMoreOverlay = false;

  bool _showMatchOverlay = false;
  late final AnimationController _matchCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final ConfettiController _confettiCtrl =
  ConfettiController(duration: const Duration(milliseconds: 1600));

  final AudioPlayer _player = AudioPlayer();

  static const Color _softBikeYellow = Color(0xFFF4C542);

  static const Color _grayBgTop = Color(0xFFF2F3F7);
  static const Color _grayBgMid = Color(0xFFE9ECF2);
  static const Color _grayBgBottom = Color(0xFFE2E6EE);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCurrentUserProfile();
      await _loadPlan();
      await _loadLiveCounters();
      await _loadProfiles();
    });
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _confettiCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  String? get _myUid => supabase.auth.currentUser?.id;

  String _normalizedPlan(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'gratuit' || v == 'free') return 'free';
    if (v == 'premium') return 'premium';
    if (v == 'ultra' || v == 'ultra premium' || v == 'ultrapremium') {
      return 'ultra';
    }
    return 'free';
  }

  bool get _isFree => _normalizedPlan(currentPlan) == 'free';
  bool get _isPremium => _normalizedPlan(currentPlan) == 'premium';
  bool get _isUltra => _normalizedPlan(currentPlan) == 'ultra';

  String _searchTypeLabel(String value) {
    switch (value) {
      case 'amour':
        return '❤️ Amour';
      case 'amitie':
        return '🤝 Amitié';
      case 'les_deux':
        return '❤️🤝 Les deux';
      default:
        return value;
    }
  }

  String? _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  bool? _readBoolMaybe(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.trim().toLowerCase();
        if (v == 'true' || v == '1' || v == 'yes') return true;
        if (v == 'false' || v == '0' || v == 'no') return false;
      }
    }
    return null;
  }

  int _readInt(Map<String, dynamic> row, List<String> keys,
      {int fallback = 100}) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  DateTime? _readDateTime(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value == null) continue;
      try {
        return DateTime.parse(value.toString()).toLocal();
      } catch (_) {}
    }
    return null;
  }

  String? _normalizeGender(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return null;

    if ([
      'male',
      'm',
      'man',
      'boy',
      'homme',
      'masculin',
    ].contains(value)) {
      return 'male';
    }

    if ([
      'female',
      'f',
      'woman',
      'girl',
      'femme',
      'féminin',
      'feminin',
    ].contains(value)) {
      return 'female';
    }

    return null;
  }

  String? _extractGender(Map<String, dynamic> row) {
    return _normalizeGender(
      _readString(row, ['gender', 'sex']),
    );
  }

  String? _extractPreferredGender(Map<String, dynamic> row) {
    final raw = _readString(
      row,
      [
        'preferred_gender',
        'interested_in',
        'seeking_gender',
        'looking_gender',
      ],
    );

    if (raw == null) return null;

    final v = raw.trim().toLowerCase();

    if ([
      'all',
      'any',
      'tous',
      'toutes',
      'both',
      'everyone',
    ].contains(v)) {
      return 'all';
    }

    return _normalizeGender(v);
  }

  String? _oppositeGender(String? gender) {
    if (gender == 'male') return 'female';
    if (gender == 'female') return 'male';
    return null;
  }

  String? _effectiveGenderTarget() {
    final opposite = _oppositeGender(_myGender);
    if (opposite != null) return opposite;

    if (_myPreferredGender == 'all') return null;
    return _myPreferredGender;
  }

  String _normalizePhone(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _extractPhone(Map<String, dynamic> row) {
    return _normalizePhone(
      _readString(
        row,
        [
          'phone',
          'phone_number',
          'phone_e164',
          'phoneNumber',
          'numero',
          'numero_telephone',
          'telephone',
        ],
      ),
    );
  }

  String? _extractBlockedUserId(Map<String, dynamic> row) {
    return _readString(
      row,
      [
        'blocked_user_id',
        'target_user_id',
        'blocked_profile_id',
        'profile_id',
        'to_user',
        'blocked_id',
      ],
    );
  }

  String? _extractOwnerId(Map<String, dynamic> row) {
    return _readString(
      row,
      [
        'owner_user_id',
        'from_user',
        'current_user_id',
        'blocker_id',
      ],
    );
  }

  String _extractBlockedPhone(Map<String, dynamic> row) {
    return _normalizePhone(
      _readString(
        row,
        [
          'blocked_phone_e164',
          'blocked_phone',
          'blocked_number',
          'blocked_phone_number',
          'phone_number',
          'phone',
          'numero',
        ],
      ),
    );
  }

  bool _profileIsVisible(Map<String, dynamic> row) {
    final isActive = _readBoolMaybe(
      row,
      ['is_active', 'active', 'account_enabled'],
    ) ??
        true;
    final isDisabled = _readBoolMaybe(
      row,
      ['account_disabled', 'disabled', 'is_disabled', 'is_deactivated'],
    ) ??
        false;
    final isDiscoverable = _readBoolMaybe(
      row,
      ['is_discoverable', 'discoverable', 'swipe_visible'],
    ) ??
        true;
    final hiddenFromSwipe = _readBoolMaybe(
      row,
      ['hidden_from_swipe', 'hide_from_swipe', 'is_hidden_from_swipe'],
    ) ??
        false;

    final status =
    (_readString(row, ['status', 'account_status']) ?? '').toLowerCase();

    if (!isActive) return false;
    if (isDisabled) return false;
    if (!isDiscoverable) return false;
    if (hiddenFromSwipe) return false;
    if (status == 'inactive' ||
        status == 'disabled' ||
        status == 'deactivated' ||
        status == 'hidden') {
      return false;
    }

    return true;
  }

  bool _passesPreferenceGate({
    required String? targetGender,
    required String? otherGender,
  }) {
    if (targetGender == null) return true;
    if (otherGender == null) return false;
    return targetGender == otherGender;
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = _myUid;
    if (uid == null) return;

    try {
      final raw = await supabase
          .from('profiles')
          .select('*')
          .eq('id', uid)
          .maybeSingle();

      if (raw == null) return;

      final row = Map<String, dynamic>.from(raw as Map);

      _myGender = _extractGender(row);
      _myPreferredGender = _extractPreferredGender(row);
      _myPhone = _extractPhone(row);
      _myAccountHidden = !_profileIsVisible(row);
    } catch (e) {
      debugPrint('_loadCurrentUserProfile error: $e');
    }
  }

  Future<Set<String>> _loadOwnBlockedUserIds() async {
    final uid = _myUid;
    if (uid == null) return {};

    final results = <String>{};

    try {
      final raw = await supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);

      for (final item in (raw as List)) {
        final row = Map<String, dynamic>.from(item as Map);
        final blockedId = row['blocked_id']?.toString().trim();
        if (blockedId != null && blockedId.isNotEmpty && blockedId != uid) {
          results.add(blockedId);
        }
      }
    } catch (e) {
      debugPrint('_loadOwnBlockedUserIds classic error: $e');
    }

    return results;
  }

  Future<Set<String>> _loadOwnBlockedPhones() async {
    final uid = _myUid;
    if (uid == null) return {};

    final results = <String>{};

    try {
      final raw = await supabase
          .from('discreet_blocks')
          .select('owner_user_id, blocked_phone_e164')
          .eq('owner_user_id', uid);

      for (final item in (raw as List)) {
        final row = Map<String, dynamic>.from(item as Map);
        final phone = _extractBlockedPhone(row);
        if (phone.isNotEmpty) {
          results.add(phone);
        }
      }
    } catch (e) {
      debugPrint('_loadOwnBlockedPhones error: $e');
    }

    return results;
  }

  Future<Set<String>> _loadUsersBlockingMe() async {
    final uid = _myUid;
    if (uid == null) return {};

    final results = <String>{};

    try {
      final raw = await supabase
          .from('user_blocks')
          .select('blocker_id')
          .eq('blocked_id', uid);

      for (final item in (raw as List)) {
        final row = Map<String, dynamic>.from(item as Map);
        final blockerId = row['blocker_id']?.toString().trim();
        if (blockerId != null && blockerId.isNotEmpty && blockerId != uid) {
          results.add(blockerId);
        }
      }
    } catch (e) {
      debugPrint('_loadUsersBlockingMe classic error: $e');
    }

    if (_myPhone.isEmpty) return results;

    try {
      final raw = await supabase
          .from('discreet_blocks')
          .select('owner_user_id, blocked_phone_e164')
          .eq('blocked_phone_e164', _myPhone);

      for (final item in (raw as List)) {
        final row = Map<String, dynamic>.from(item as Map);
        final ownerId = _extractOwnerId(row);
        if (ownerId != null && ownerId.isNotEmpty && ownerId != uid) {
          results.add(ownerId);
        }
      }
    } catch (e) {
      debugPrint('_loadUsersBlockingMe by phone error: $e');
    }

    return results;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesMeta(
      Set<String> ids,
      ) async {
    if (ids.isEmpty) return {};

    try {
      final raw = await supabase
          .from('profiles')
          .select('*')
          .inFilter('id', ids.toList());

      final rows = List<Map<String, dynamic>>.from(raw as List);
      return {
        for (final row in rows) row['id'].toString(): row,
      };
    } catch (e) {
      debugPrint('_fetchProfilesMeta error: $e');
      return {};
    }
  }

  int _profileRank(Map<String, dynamic> row, {required int photoCount}) {
    int score = 0;

    final trust = _readInt(row, ['trust_score', 'score'], fallback: 100);
    score += trust * 10;

    final verified =
        _readBoolMaybe(row, ['is_verified', 'verified']) ?? false;
    if (verified) score += 400;

    final online = _readBoolMaybe(row, ['is_online', 'online']) ?? false;
    if (online) score += 350;

    if (photoCount > 0) score += 250;
    if (photoCount >= 2) score += 80;

    final lastSeen = _readDateTime(row, ['last_seen_at', 'updated_at']);
    if (lastSeen != null) {
      final hoursAgo = DateTime.now().difference(lastSeen).inHours;
      if (hoursAgo <= 6) {
        score += 220;
      } else if (hoursAgo <= 24) {
        score += 140;
      } else if (hoursAgo <= 72) {
        score += 80;
      }
    }

    score += Random(row['id'].toString().hashCode).nextInt(45);

    return score;
  }

  Future<void> _loadPlan() async {
    try {
      final res = await supabase.rpc('get_current_plan');

      String p = 'free';

      if (res is List && res.isNotEmpty) {
        final row = Map<String, dynamic>.from(res.first as Map);
        p = _normalizedPlan((row['plan'] ?? 'free').toString());
      } else if (res is Map) {
        final row = Map<String, dynamic>.from(res);
        p = _normalizedPlan((row['plan'] ?? 'free').toString());
      }

      if (!mounted) return;
      setState(() => currentPlan = p);
    } catch (e) {
      debugPrint("get_current_plan error: $e");
      if (!mounted) return;
      setState(() => currentPlan = 'free');
    }
  }

  Future<void> _loadLiveCounters() async {
    final uid = _myUid;
    if (uid == null) return;

    try {
      final matchRows = await supabase
          .from('matches')
          .select('id, user1, user2')
          .or('user1.eq.$uid,user2.eq.$uid');

      final matchList = List<Map<String, dynamic>>.from(matchRows as List);

      final matchedUserIds = <String>{};
      for (final row in matchList) {
        final user1 = row['user1']?.toString();
        final user2 = row['user2']?.toString();
        if (user1 == null || user2 == null) continue;
        matchedUserIds.add(user1 == uid ? user2 : user1);
      }

      final likeRows = await supabase
          .from('likes')
          .select('from_user, type')
          .eq('to_user', uid)
          .inFilter('type', ['like', 'superlike']);

      final uniqueLikeSenders = <String>{};
      for (final row in List<Map<String, dynamic>>.from(likeRows as List)) {
        final fromUser = row['from_user']?.toString().trim();
        if (fromUser == null || fromUser.isEmpty) continue;
        if (matchedUserIds.contains(fromUser)) continue;
        if (_blockedUserIds.contains(fromUser)) continue;
        if (_usersBlockingMe.contains(fromUser)) continue;
        uniqueLikeSenders.add(fromUser);
      }

      if (!mounted) return;
      setState(() {
        unreadMatches = matchedUserIds.length;
        unreadLikes = uniqueLikeSenders.length;
      });
    } catch (e) {
      debugPrint('_loadLiveCounters error: $e');
    }
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;

    setState(() => _loadingProfiles = true);

    try {
      await _loadCurrentUserProfile();
      _blockedUserIds = await _loadOwnBlockedUserIds();
      _blockedPhones = await _loadOwnBlockedPhones();
      _usersBlockingMe = await _loadUsersBlockingMe();
      await _loadLiveCounters();

      if (_myAccountHidden) {
        if (!mounted) return;
        setState(() {
          _allUsers = [];
          _index = 0;
          _showNoMoreOverlay = true;
          _loadingProfiles = false;
        });
        return;
      }

      final res = await supabase.rpc(
        'get_swipe_profiles',
        params: {
          'p_city': _cityFilter,
          'p_keyword': _bioKeyword.trim().isEmpty ? null : _bioKeyword.trim(),
          'p_search': _searchTypeFilter,
          'p_age_min': _ageMin,
          'p_age_max': _ageMax,
        },
      );

      final rows = List<Map<String, dynamic>>.from((res ?? []) as List);
      final candidateIds = rows.map((e) => e['id'].toString()).toSet();
      final profilesMeta = await _fetchProfilesMeta(candidateIds);
      final now = DateTime.now();

      final List<_RankedUserCardData> rankedProfiles = [];
      final targetGender = _effectiveGenderTarget();

      for (final row in rows) {
        final id = row['id'].toString();
        if (id.isEmpty) continue;
        if (id == _myUid) continue;

        final meta = profilesMeta[id] ?? row;

        if (!_profileIsVisible(meta)) continue;
        if (_blockedUserIds.contains(id)) continue;
        if (_usersBlockingMe.contains(id)) continue;

        final targetPhone = _extractPhone(meta);
        if (targetPhone.isNotEmpty && _blockedPhones.contains(targetPhone)) {
          continue;
        }

        final otherGender = _extractGender(meta);
        if (!_passesPreferenceGate(
          targetGender: targetGender,
          otherGender: otherGender,
        )) {
          continue;
        }

        final birthYear = row['birth_year'] as int?;
        final age = birthYear == null ? 18 : max(18, now.year - birthYear);

        final photosRaw = row['photos'] ?? meta['photos'];
        final List<String> photos = photosRaw is List
            ? photosRaw
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
            : <String>[];

        final avatarUrl =
        (row['avatar_url'] ?? meta['avatar_url'] ?? '').toString();

        final finalImages = photos.isNotEmpty
            ? photos
            : (avatarUrl.isNotEmpty ? [avatarUrl] : <String>[]);

        final user = _UserCardData(
          id: id,
          firstName:
          (row['first_name'] ?? meta['first_name'] ?? '').toString(),
          age: age,
          city: (row['city'] ?? meta['city'] ?? '').toString(),
          isVerified:
          ((row['is_verified'] ?? meta['is_verified']) ?? false) == true,
          images: finalImages,
          bio: (row['bio'] ?? meta['bio'] ?? '').toString(),
          searchType:
          (row['looking_for'] ?? meta['looking_for'] ?? 'amour')
              .toString(),
          gender: otherGender,
          trustScore: _readInt(meta, ['trust_score', 'score'], fallback: 100),
          lastSeenAt: _readDateTime(meta, ['last_seen_at', 'updated_at']),
        );

        if (user.trustScore < 40) continue;

        rankedProfiles.add(
          _RankedUserCardData(
            data: user,
            rank: _profileRank(meta, photoCount: finalImages.length),
          ),
        );
      }

      rankedProfiles.sort((a, b) => b.rank.compareTo(a.rank));
      final profiles = rankedProfiles.map((e) => e.data).toList();

      if (!mounted) return;
      setState(() {
        _allUsers = profiles;
        _index = 0;
        _showNoMoreOverlay = profiles.isEmpty;
        _loadingProfiles = false;
      });
    } catch (e) {
      debugPrint('get_swipe_profiles error: $e');
      if (!mounted) return;
      setState(() {
        _allUsers = [];
        _index = 0;
        _showNoMoreOverlay = true;
        _loadingProfiles = false;
      });
    }
  }

  List<_UserCardData> get _filteredUsers => _allUsers;

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        String? tempCity = _cityFilter;
        String tempKw = _bioKeyword;
        String? tempSearchType = _searchTypeFilter;
        double tempAgeMin = _ageMin.toDouble();
        double tempAgeMax = _ageMax.toDouble();

        return Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
            top: 10,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: StatefulBuilder(
                builder: (context, setLocal) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(0.92)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Filtres",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Mot-clé (bio)",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            initialValue: tempKw,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration:
                            _modernInputDeco("Ex: sérieux, sport, voyage..."),
                            onChanged: (v) => setLocal(() => tempKw = v),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Ville",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            value: tempCity,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            decoration: _modernInputDeco("Toutes les villes"),
                            iconEnabledColor: Colors.black87,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text("Toutes les villes"),
                              ),
                              ..._cities.map(
                                    (c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c),
                                ),
                              ),
                            ],
                            onChanged: (v) => setLocal(() => tempCity = v),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Recherche",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            value: tempSearchType,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            decoration:
                            _modernInputDeco("Amour, Amitié ou les deux"),
                            iconEnabledColor: Colors.black87,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text("Toutes les recherches"),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'amour',
                                child: Text(_searchTypeLabel('amour')),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'amitie',
                                child: Text(_searchTypeLabel('amitie')),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'les_deux',
                                child: Text(_searchTypeLabel('les_deux')),
                              ),
                            ],
                            onChanged: (v) =>
                                setLocal(() => tempSearchType = v),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Âge : ${tempAgeMin.round()} - ${tempAgeMax.round()} ans",
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RangeSlider(
                            values: RangeValues(tempAgeMin, tempAgeMax),
                            min: 18,
                            max: 65,
                            divisions: 47,
                            labels: RangeLabels(
                              tempAgeMin.round().toString(),
                              tempAgeMax.round().toString(),
                            ),
                            onChanged: (values) {
                              setLocal(() {
                                tempAgeMin = values.start;
                                tempAgeMax = values.end;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _pillButton(
                                  label: "Réinitialiser",
                                  bg: Colors.white,
                                  fg: Colors.black87,
                                  borderColor: Colors.black12,
                                  onTap: () async {
                                    setState(() {
                                      _cityFilter = null;
                                      _bioKeyword = "";
                                      _searchTypeFilter = null;
                                      _ageMin = 18;
                                      _ageMax = 50;
                                      _index = 0;
                                      _showNoMoreOverlay = false;
                                    });
                                    Navigator.pop(context);
                                    await _loadProfiles();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _pillButton(
                                  label: "Appliquer",
                                  bg: const Color(0xFF7C3AED),
                                  fg: Colors.white,
                                  borderColor: Colors.transparent,
                                  onTap: () async {
                                    setState(() {
                                      _cityFilter = tempCity;
                                      _bioKeyword = tempKw;
                                      _searchTypeFilter = tempSearchType;
                                      _ageMin = tempAgeMin.round();
                                      _ageMax = tempAgeMax.round();
                                      _index = 0;
                                      _showNoMoreOverlay = false;
                                    });
                                    Navigator.pop(context);
                                    await _loadProfiles();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _goSubscription() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    await _loadPlan();
    await _loadLiveCounters();
    await _loadProfiles();
  }

  Future<void> _showLimitPopup(LimitAction action) async {
    String body;

    switch (action) {
      case LimitAction.rewind:
        body = _isFree
            ? "Retour : 1/jour en Gratuit.\nPasse Premium (5/jour) ou Ultra (illimité)."
            : "Retour : limite atteinte.\nPasse Ultra pour l’illimité.";
        break;
      case LimitAction.superlike:
        body = _isFree
            ? "Super Like : 1/jour en Gratuit.\nPasse Premium (5/jour) ou Ultra (illimité)."
            : "Super Like : limite atteinte.\nPasse Ultra pour l’illimité.";
        break;
      case LimitAction.swipe:
        body = _isFree
            ? "Swipes : limite quotidienne atteinte.\nPasse Premium ou Ultra pour les swipes illimités."
            : "Swipes : limite atteinte.";
        break;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _glassGroup(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Limite atteinte",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                      const Icon(Icons.close_rounded, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.black87.withOpacity(0.82),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                if (_isFree) ...[
                  _upgradeCard(
                    title: "Premium — 2 000 F/mois",
                    subtitle:
                    "Rewinds 5/jour • Super Likes 5/jour • Swipes illimités • 1 chance/cadeau du mois",
                    onTap: () => Navigator.pop(context, 'premium'),
                  ),
                  const SizedBox(height: 10),
                ],
                _upgradeCard(
                  title: "Ultra — 5 000 F/mois",
                  subtitle:
                  "Rewinds illimités • Mode discret • Swipes illimités • 2 chances/cadeau du mois",
                  onTap: () => Navigator.pop(context, 'ultra'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Plus tard",
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == 'premium' || choice == 'ultra') {
      await _goSubscription();
    }
  }

  Widget _upgradeCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
          color: Colors.white.withOpacity(0.92),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.black87.withOpacity(0.74),
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _consumeSwipeRpc() async {
    try {
      final res = await supabase.rpc('consume_swipe');
      debugPrint('consume_swipe => $res');
      return res == true;
    } catch (e) {
      debugPrint('consume_swipe error: $e');
      return false;
    }
  }

  Future<bool> _consumeSuperLikeAndSwipeRpc() async {
    try {
      final res = await supabase.rpc('consume_superlike_and_swipe');
      debugPrint('consume_superlike_and_swipe => $res');
      return res == true;
    } catch (e) {
      debugPrint('consume_superlike_and_swipe error: $e');
      return false;
    }
  }

  Future<bool> _consumeRewindRpc() async {
    try {
      final res = await supabase.rpc('consume_rewind');
      debugPrint('consume_rewind => $res');
      return res == true;
    } catch (e) {
      debugPrint('consume_rewind error: $e');
      return false;
    }
  }

  Future<bool> _consumeOrPopup(LimitAction action) async {
    final uid = _myUid;
    if (uid == null) {
      _toast("Tu dois être connectée.");
      return false;
    }

    bool ok = false;

    if (action == LimitAction.swipe) {
      ok = await _consumeSwipeRpc();
    } else if (action == LimitAction.superlike) {
      ok = await _consumeSuperLikeAndSwipeRpc();
    } else if (action == LimitAction.rewind) {
      ok = await _consumeRewindRpc();
    }

    if (!ok) {
      await _showLimitPopup(action);
      return false;
    }

    return true;
  }

  Future<void> _registerSwipe({
    required String toUserId,
    required String type,
  }) async {
    final uid = _myUid;
    if (uid == null) return;

    await supabase.from('likes').insert({
      'from_user': uid,
      'to_user': toUserId,
      'type': type,
      'day': DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  Future<bool> _hasReciprocalLike(String otherUserId) async {
    final uid = _myUid;
    if (uid == null) return false;

    final res = await supabase
        .from('likes')
        .select('id')
        .eq('from_user', otherUserId)
        .eq('to_user', uid)
        .inFilter('type', ['like', 'superlike'])
        .limit(1);

    return (res as List).isNotEmpty;
  }

  Future<void> _ensureMatchExists(String otherUserId) async {
    final uid = _myUid;
    if (uid == null) return;

    final ordered = [uid, otherUserId]..sort();
    final user1 = ordered[0];
    final user2 = ordered[1];

    final existing = await supabase
        .from('matches')
        .select('id')
        .eq('user1', user1)
        .eq('user2', user2)
        .limit(1);

    if ((existing as List).isEmpty) {
      await supabase.from('matches').insert({
        'user1': user1,
        'user2': user2,
        'created_at': DateTime.now().toIso8601String(),
        'last_message_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _actionPass() async {
    final users = _filteredUsers;
    if (users.isEmpty || _showNoMoreOverlay) return;
    if (_busySwipe) return;
    _busySwipe = true;

    try {
      final ok = await _consumeOrPopup(LimitAction.swipe);
      if (!ok) return;

      final current = users[_index.clamp(0, users.length - 1)];

      await _registerSwipe(
        toUserId: current.id,
        type: 'pass',
      );

      _nextCard();
    } finally {
      _busySwipe = false;
    }
  }

  Future<void> _actionLike() async {
    final users = _filteredUsers;
    if (users.isEmpty || _showNoMoreOverlay) return;
    if (_busySwipe) return;
    _busySwipe = true;

    try {
      final ok = await _consumeOrPopup(LimitAction.swipe);
      if (!ok) return;

      final current = users[_index.clamp(0, users.length - 1)];

      await _registerSwipe(
        toUserId: current.id,
        type: 'like',
      );

      final isMatch = await _hasReciprocalLike(current.id);

      if (isMatch) {
        await _ensureMatchExists(current.id);
        _lastMatchedUser = current;
        await _triggerMatchOverlay();
      }

      await _loadLiveCounters();
      _nextCard();
    } finally {
      _busySwipe = false;
    }
  }

  Future<void> _actionSuperLike() async {
    final users = _filteredUsers;
    if (users.isEmpty || _showNoMoreOverlay) return;
    if (_busySuperlike) return;
    _busySuperlike = true;

    try {
      final ok = await _consumeOrPopup(LimitAction.superlike);
      if (!ok) return;

      final current = users[_index.clamp(0, users.length - 1)];

      await _registerSwipe(
        toUserId: current.id,
        type: 'superlike',
      );

      final isMatch = await _hasReciprocalLike(current.id);

      if (isMatch) {
        await _ensureMatchExists(current.id);
        _lastMatchedUser = current;
        await _triggerMatchOverlay();
      }

      await _loadLiveCounters();
      _nextCard();
    } finally {
      _busySuperlike = false;
    }
  }

  Future<void> _actionRewind() async {
    final users = _filteredUsers;
    if (users.isEmpty) return;
    if (_index <= 0) return;

    if (_busyRewind) return;
    _busyRewind = true;

    try {
      final ok = await _consumeOrPopup(LimitAction.rewind);
      if (!ok) return;
      setState(() => _index -= 1);
    } finally {
      _busyRewind = false;
    }
  }

  Future<void> _triggerMatchOverlay() async {
    if (!mounted) return;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    setState(() => _showMatchOverlay = true);

    _matchCtrl.forward(from: 0);
    _confettiCtrl.play();

    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/match_pop.mp3'));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    setState(() => _showMatchOverlay = false);
  }

  Future<void> _refreshProfiles() async {
    setState(() => _showNoMoreOverlay = false);
    await _loadPlan();
    await _loadLiveCounters();
    await _loadProfiles();
  }

  void _nextCard() {
    final users = _filteredUsers;
    if (users.isEmpty) return;

    if (_index < users.length - 1) {
      setState(() {
        _index += 1;
        _showNoMoreOverlay = false;
      });
    } else {
      setState(() => _showNoMoreOverlay = true);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfiles) {
      return const Scaffold(
        backgroundColor: _grayBgMid,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_myAccountHidden) {
      return Scaffold(
        backgroundColor: _grayBgMid,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _glassGroup(
              radius: 26,
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    color: Colors.black87,
                    size: 38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Ton compte est actuellement désactivé",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Réactive ton compte dans les paramètres pour réapparaître dans les swipes et continuer à découvrir des profils.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final users = _filteredUsers;

    final _UserCardData? current = (_showNoMoreOverlay || users.isEmpty)
        ? null
        : users[_index.clamp(0, users.length - 1)];

    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    const double navApproxHeight = 68;
    final double bottomNavBottom = 10 + safeBottom;
    final double actionButtonsBottom = bottomNavBottom + navApproxHeight + 10;

    final topY = 8 + safeTop;

    return Scaffold(
      backgroundColor: _grayBgMid,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _grayBgTop,
                    _grayBgMid,
                    _grayBgBottom,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topY,
            left: 14,
            right: 14,
            child: _glassGroup(
              radius: 28,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _glassIconButton(
                    icon: Icons.tune_rounded,
                    onTap: _openFilterSheet,
                    size: 50,
                    accent: const Color(0xFF7C3AED),
                  ),
                  const Spacer(),
                  _logoGlassButton(
                    assetPath: "assets/images/logo.png",
                    size: 50,
                  ),
                  const Spacer(),
                  _glassIconButton(
                    icon: Icons.workspace_premium_rounded,
                    onTap: _goSubscription,
                    size: 50,
                    accent: _softBikeYellow,
                    glow: true,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: topY + 70,
            left: 14,
            right: 14,
            bottom: actionButtonsBottom + 88,
            child: _glassGroup(
              radius: 28,
              padding: const EdgeInsets.all(12),
              child: _ProfileCardBig(
                user: current,
                showNoMore: _showNoMoreOverlay,
                emptyText: "Aucun profil pour le moment.\nReviens plus tard 🙂",
                searchTypeLabelBuilder: _searchTypeLabel,
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: actionButtonsBottom,
            child: _glassGroup(
              radius: 999,
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundActionModern(
                    icon: Icons.undo_rounded,
                    bg: const Color(0xFFFB8C00),
                    onTap: _actionRewind,
                    size: 58,
                  ),
                  _roundActionModern(
                    icon: Icons.close_rounded,
                    bg: const Color(0xFFE53935),
                    onTap: _actionPass,
                    size: 58,
                  ),
                  _roundActionModern(
                    icon: Icons.star_rounded,
                    bg: const Color(0xFF1E88E5),
                    onTap: _actionSuperLike,
                    size: 58,
                  ),
                  _roundActionModern(
                    icon: Icons.favorite_rounded,
                    bg: const Color(0xFF43A047),
                    onTap: _actionLike,
                    size: 58,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomNavBottom,
            child: _glassGroup(
              radius: 999,
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navIconBadge(
                    icon: Icons.chat_bubble_outline,
                    badgeCount: unreadMatches,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MatchesScreen(),
                        ),
                      );
                      await _loadLiveCounters();
                      await _loadProfiles();
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.visibility_off_outlined,
                    badgeCount: 0,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiscreetModeScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
                      await _loadCurrentUserProfile();
                      await _loadLiveCounters();
                      await _loadProfiles();
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.favorite_border,
                    badgeCount: unreadLikes,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LikesReceivedScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
                      await _loadLiveCounters();
                      await _loadProfiles();
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.person_outline,
                    badgeCount: 0,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
                      await _loadCurrentUserProfile();
                      await _loadPlan();
                      await _loadLiveCounters();
                      await _loadProfiles();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_showNoMoreOverlay)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: _NoMoreProfilesOverlay(
                  onClose: () => setState(() => _showNoMoreOverlay = false),
                  onRefresh: _refreshProfiles,
                ),
              ),
            ),
          if (_showMatchOverlay)
            Positioned.fill(
              child: _MatchCelebrationOverlay(
                controller: _matchCtrl,
                confettiController: _confettiCtrl,
                myImagePath: "assets/images/logo.png",
                matchImagePath: _lastMatchedUser?.images.isNotEmpty == true
                    ? _lastMatchedUser!.images.first
                    : "assets/images/logo.png",
                matchName: _lastMatchedUser?.firstName ?? "Ton match",
                onClose: () => setState(() => _showMatchOverlay = false),
                onMessage: () async {
                  setState(() => _showMatchOverlay = false);
                  await _loadLiveCounters();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCardBig extends StatefulWidget {
  final _UserCardData? user;
  final String emptyText;
  final bool showNoMore;
  final String Function(String value) searchTypeLabelBuilder;

  const _ProfileCardBig({
    required this.user,
    required this.emptyText,
    required this.showNoMore,
    required this.searchTypeLabelBuilder,
  });

  @override
  State<_ProfileCardBig> createState() => _ProfileCardBigState();
}

class _ProfileCardBigState extends State<_ProfileCardBig> {
  final PageController _pageCtrl = PageController();
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant _ProfileCardBig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _photoIndex = 0;
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    if (widget.showNoMore || u == null) {
      return Center(
        child: Text(
          widget.emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: max(1, u.images.length),
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (_, i) {
                      final path = u.images.isNotEmpty ? u.images[i] : null;

                      if (path == null || path.isEmpty) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 44,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      }

                      final isRemote = path.startsWith('http');

                      if (isRemote) {
                        return Image.network(
                          path,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 44,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }

                      return Image.asset(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 44,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (u.images.length > 1)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _photoDots(
                        count: u.images.length,
                        active: _photoIndex,
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _miniVerifiedBadge(
                    isVerified: u.isVerified,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                "${u.firstName}, ${u.age} ans",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Colors.black54,
              size: 18,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                u.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _searchTypeChip(widget.searchTypeLabelBuilder(u.searchType)),
        ),
        const SizedBox(height: 10),
        Text(
          u.bio,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black87.withOpacity(0.88),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _photoDots({required int count, required int active}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(count, (i) {
              final on = i == active;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: on ? Colors.black87 : Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _searchTypeChip(String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.80),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _glassGroup({
  required Widget child,
  double radius = 28,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.58),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.88)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

Widget _glassIconButton({
  required IconData icon,
  required VoidCallback onTap,
  double size = 56,
  Color? accent,
  bool glow = false,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
            boxShadow: glow
                ? [
              BoxShadow(
                color: (accent ?? Colors.black87).withOpacity(0.14),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: accent ?? Colors.black87, size: 28),
        ),
      ),
    ),
  );
}

Widget _logoGlassButton({required String assetPath, double size = 50}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

Widget _roundActionModern({
  required IconData icon,
  required Color bg,
  required VoidCallback onTap,
  double size = 66,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    ),
  );
}

Widget _navIconBadge({
  required IconData icon,
  required VoidCallback onTap,
  int badgeCount = 0,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: Colors.black87),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white),
              ),
              child: Text(
                badgeCount > 99 ? "99+" : "$badgeCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _miniVerifiedBadge({
  required bool isVerified,
  bool compact = false,
}) {
  final icon =
  isVerified ? Icons.verified_rounded : Icons.info_outline_rounded;
  final color = isVerified ? const Color(0xFF00A86B) : Colors.black87;

  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white),
        ),
        child: Icon(icon, color: color, size: compact ? 14 : 16),
      ),
    ),
  );
}

InputDecoration _modernInputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Colors.black45,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
    ),
  );
}

Widget _pillButton({
  required String label,
  required Color bg,
  required Color fg,
  required Color borderColor,
  required VoidCallback onTap,
}) {
  return SizedBox(
    height: 44,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: borderColor),
        ),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
  );
}

class _NoMoreProfilesOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onRefresh;

  const _NoMoreProfilesOverlay({
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: min(MediaQuery.of(context).size.width - 28, 420),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        "Tu as vu tous les profils 🎉",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Reviens plus tard ou relance la liste.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () async => onRefresh(),
                          child: const Text(
                            "Rafraîchir",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchCelebrationOverlay extends StatelessWidget {
  final AnimationController controller;
  final ConfettiController confettiController;
  final String myImagePath;
  final String matchImagePath;
  final String matchName;
  final VoidCallback onClose;
  final VoidCallback onMessage;

  const _MatchCelebrationOverlay({
    required this.controller,
    required this.confettiController,
    required this.myImagePath,
    required this.matchImagePath,
    required this.matchName,
    required this.onClose,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    final scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    final heartScale = Tween<double>(begin: 0.75, end: 1.35).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    final glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeIn),
    );

    return Material(
      color: Colors.black.withOpacity(0.34),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.10,
              numberOfParticles: 36,
              gravity: 0.24,
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) {
                    return Container(
                      width: min(MediaQuery.of(context).size.width - 32, 430),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent
                                .withOpacity(0.22 * glowOpacity.value),
                            blurRadius: 42,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 600),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFFE63946),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Text("C’EST UN MATCH"),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 102,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      left: 86,
                                      child: _roundPhoto(matchImagePath),
                                    ),
                                    Positioned(
                                      left: 28,
                                      child: _roundPhoto(myImagePath),
                                    ),
                                    ScaleTransition(
                                      scale: heartScale,
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.redAccent,
                                        size: 52,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Toi + $matchName 💜\nVous vous êtes likés mutuellement.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black87.withOpacity(0.84),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  height: 1.28,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 46,
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE63946),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed: onMessage,
                                  child: const Text(
                                    "Envoyer un message",
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: onClose,
                                child: Text(
                                  "Plus tard",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 14 + MediaQuery.of(context).padding.top,
            right: 14,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundPhoto(String path) {
    final isRemote = path.startsWith('http');

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: isRemote
            ? Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white,
            child: const Icon(Icons.person,
                color: Colors.black54, size: 30),
          ),
        )
            : Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white,
            child: const Icon(Icons.person,
                color: Colors.black54, size: 30),
          ),
        ),
      ),
    );
  }
}

class _UserCardData {
  final String id;
  final String firstName;
  final int age;
  final String city;
  final bool isVerified;
  final List<String> images;
  final String bio;
  final String searchType;
  final String? gender;
  final int trustScore;
  final DateTime? lastSeenAt;

  const _UserCardData({
    required this.id,
    required this.firstName,
    required this.age,
    required this.city,
    required this.isVerified,
    required this.images,
    required this.bio,
    required this.searchType,
    required this.gender,
    required this.trustScore,
    required this.lastSeenAt,
  });
}

class _RankedUserCardData {
  final _UserCardData data;
  final int rank;

  const _RankedUserCardData({
    required this.data,
    required this.rank,
  });
}