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
  String? _searchTypeFilter; // amour / amitie / les_deux
  int _ageMin = 18;
  int _ageMax = 50;

  int unreadLikes = 17;
  int unreadMatches = 2;

  _UserCardData? _lastMatchedUser;

  bool _busySwipe = false;
  bool _busySuperlike = false;
  bool _busyRewind = false;

  bool _loadingProfiles = true;
  List<_UserCardData> _allUsers = [];

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

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _loadProfiles();
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _confettiCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  String? get _myUid => supabase.auth.currentUser?.id;

  bool get _isFree => currentPlan == 'free';
  bool get _isPremium => currentPlan == 'premium';
  bool get _isUltra => currentPlan == 'ultra';

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

  Future<void> _loadPlan() async {
    try {
      final res = await supabase.rpc('get_current_plan');

      if (res == null) {
        if (!mounted) return;
        setState(() => currentPlan = 'free');
        return;
      }

      if (res is List && res.isNotEmpty) {
        final row = Map<String, dynamic>.from(res.first as Map);
        final p = (row['plan'] ?? 'free').toString().toLowerCase().trim();
        if (!mounted) return;
        setState(() => currentPlan = p);
        return;
      }

      if (res is Map) {
        final row = Map<String, dynamic>.from(res);
        final p = (row['plan'] ?? 'free').toString().toLowerCase().trim();
        if (!mounted) return;
        setState(() => currentPlan = p);
        return;
      }

      if (!mounted) return;
      setState(() => currentPlan = 'free');
    } catch (e) {
      debugPrint("get_current_plan error: $e");
      if (!mounted) return;
      setState(() => currentPlan = 'free');
    }
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;

    setState(() => _loadingProfiles = true);

    try {
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

      final rows = List<Map<String, dynamic>>.from(res as List);
      final now = DateTime.now();

      final profiles = rows.map((row) {
        final birthYear = row['birth_year'] as int?;
        final age = birthYear == null ? 18 : max(18, now.year - birthYear);

        final photosRaw = row['photos'];
        final List<String> photos = photosRaw is List
            ? photosRaw.map((e) => e.toString()).toList()
            : <String>[];

        final avatarUrl = (row['avatar_url'] ?? '').toString();

        final finalImages = photos.isNotEmpty
            ? photos
            : (avatarUrl.isNotEmpty ? [avatarUrl] : <String>[]);

        return _UserCardData(
          id: row['id'].toString(),
          firstName: (row['first_name'] ?? '').toString(),
          age: age,
          city: (row['city'] ?? '').toString(),
          isVerified: (row['is_verified'] ?? false) == true,
          images: finalImages,
          bio: (row['bio'] ?? '').toString(),
          searchType: (row['looking_for'] ?? 'amour').toString(),
        );
      }).toList();

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

        return StatefulBuilder(
          builder: (context, setLocal) {
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(26),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
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
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Mot-clé (bio)",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            initialValue: tempKw,
                            style: const TextStyle(
                              color: Colors.white,
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            value: tempCity,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2330),
                            decoration: _modernInputDeco("Toutes les villes"),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.white,
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            value: tempSearchType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2330),
                            decoration:
                            _modernInputDeco("Amour, Amitié ou les deux"),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.white,
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
                            onChanged: (v) => setLocal(() => tempSearchType = v),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Âge : ${tempAgeMin.round()} - ${tempAgeMax.round()} ans",
                            style: const TextStyle(
                              color: Colors.white,
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
                                  bg: Colors.white.withOpacity(0.14),
                                  fg: Colors.white,
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
                  ),
                ),
              ),
            );
          },
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
            ? "Swipes : limite quotidienne atteinte.\nPasse Premium ou Ultra pour swipes illimités."
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
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                if (_isFree) ...[
                  _upgradeCard(
                    title: "Premium — 2 000 F/mois",
                    subtitle:
                    "Rewinds 5/jour • Super Likes 5/jour • Swipes illimités",
                    onTap: () => Navigator.pop(context, 'premium'),
                  ),
                  const SizedBox(height: 10),
                ],
                _upgradeCard(
                  title: "Ultra — 5 000 F/mois",
                  subtitle:
                  "Rewinds illimités • Mode discret • 2 chances dîner",
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
                        color: Colors.white.withOpacity(0.75),
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
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
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
      return res == true;
    } catch (e) {
      debugPrint('consume_swipe error: $e');
      return false;
    }
  }

  Future<bool> _consumeSuperLikeAndSwipeRpc() async {
    try {
      final res = await supabase.rpc('consume_superlike_and_swipe');
      return res == true;
    } catch (e) {
      debugPrint('consume_superlike_and_swipe error: $e');
      return false;
    }
  }

  Future<bool> _consumeRewindRpc() async {
    try {
      final res = await supabase.rpc('consume_rewind');
      return res == true;
    } catch (e) {
      debugPrint('consume_rewind error: $e');
      return false;
    }
  }

  Future<bool> _consumeOrPopup(LimitAction action) async {
    final uid = _myUid;
    if (uid == null) {
      _toast("Tu dois être connecté.");
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
        body: Center(
          child: CircularProgressIndicator(),
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
      backgroundColor: const Color(0xFF1D1822),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF241D2B),
                    Color(0xFF1D1822),
                    Color(0xFF17141C),
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
                    accent: const Color(0xFF9B6BFF),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MatchesScreen(),
                        ),
                      );
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.visibility_off_outlined,
                    badgeCount: 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiscreetModeScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.favorite_border,
                    badgeCount: unreadLikes,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LikesReceivedScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
                    },
                  ),
                  _navIconBadge(
                    icon: Icons.person_outline,
                    badgeCount: 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            currentPlan: currentPlan,
                            onUpgradeTap: _goSubscription,
                          ),
                        ),
                      );
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
                onMessage: () {
                  setState(() => _showMatchOverlay = false);
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
            color: Colors.white,
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
                          color: Colors.white.withOpacity(0.06),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 44,
                              color: Colors.white70,
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
                            color: Colors.white.withOpacity(0.06),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 44,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }

                      return Image.asset(
                          path,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withOpacity(0.06),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 44,
                                color: Colors.white70,
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
                  color: Colors.white,
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
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                u.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
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
            color: Colors.white.withOpacity(0.92),
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
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                  color: on ? Colors.white : Colors.white.withOpacity(0.45),
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
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
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
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: glow
                ? [
              BoxShadow(
                color: (accent ?? Colors.white).withOpacity(0.18),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ]
                : null,
          ),
          child: Icon(icon, color: accent ?? Colors.white, size: 28),
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
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
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
            color: Colors.black.withOpacity(0.22),
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
            color: Colors.white.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Icon(icon, size: 24, color: Colors.white),
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
                border: Border.all(color: Colors.white.withOpacity(0.35)),
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
  final color = isVerified ? const Color(0xFF00E676) : Colors.white;

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
          color: Colors.black.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
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
      color: Colors.white.withOpacity(0.60),
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
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
          side: BorderSide(color: Colors.white.withOpacity(0.18)),
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
      color: Colors.black.withOpacity(0.30),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: min(MediaQuery.of(context).size.width - 28, 420),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Reviens plus tard ou relance la liste.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
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
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
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
      color: Colors.black.withOpacity(0.62),
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
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent
                                .withOpacity(0.35 * glowOpacity.value),
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
                                  color: Colors.white,
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
                                  color: Colors.white.withOpacity(0.88),
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
                                    color: Colors.white.withOpacity(0.75),
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
              icon: const Icon(Icons.close_rounded, color: Colors.white),
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
        border: Border.all(color: Colors.white.withOpacity(0.88), width: 2.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
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
            color: Colors.white.withOpacity(0.12),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        )
            : Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withOpacity(0.12),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
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

  const _UserCardData({
    required this.id,
    required this.firstName,
    required this.age,
    required this.city,
    required this.isVerified,
    required this.images,
    required this.bio,
    required this.searchType,
  });
}