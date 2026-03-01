import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎉 Confettis + 🔊 Son
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';

import '../match/matches_screen.dart';
import '../likes/likes_received_screen.dart';
import '../discreet/discreet_mode_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';

// ✅ DAILY LIMITS REPO (adapte le chemin si besoin)
import '../data/daily_limits_repo.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // ✅ Repo limits (une seule instance)
  late final DailyLimitsRepo _limitsRepo = DailyLimitsRepo(supabase);

  // ✅ Plan courant renvoyé par Supabase RPC : "gratuit" / "premium" / "ultra"
  String currentPlan = "gratuit";

  // ---- FILTRES (âge supprimé comme demandé) ----
  String? _cityFilter; // null = toutes
  String _bioKeyword = "";

  // ✅ Compteurs (badges) (démo)
  int unreadLikes = 17;
  int unreadMatches = 2;

  // ✅ Dernier match pour afficher les photos dans le popup
  _UserCardData? _lastMatchedUser;

  // ✅ Anti double clic
  bool _busySwipe = false;
  bool _busySuperlike = false;
  bool _busyRewind = false;

  // ✅ Liste villes Burkina
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

  // ---- DONNÉES FAKE (en attendant Supabase) ----
  final List<_UserCardData> _allUsers = const [
    _UserCardData(
      firstName: "Aïcha",
      age: 24,
      city: "Ouagadougou",
      isVerified: true,
      images: [
        "assets/images/sample_profile_1.jpg",
        "assets/images/sample_profile_2.jpg",
        "assets/images/sample_profile_3.jpg",
      ],
      bio: "J’aime voyager, rire et cuisiner. Ouaga vibes.",
    ),
    _UserCardData(
      firstName: "Nina",
      age: 22,
      city: "Bobo-Dioulasso",
      isVerified: false,
      images: [
        "assets/images/sample_profile_2.jpg",
      ],
      bio: "Sourire + douceur. Je cherche du sérieux.",
    ),
    _UserCardData(
      firstName: "Moussa",
      age: 29,
      city: "Ouagadougou",
      isVerified: true,
      images: [
        "assets/images/sample_profile_3.jpg",
        "assets/images/sample_profile_1.jpg",
      ],
      bio: "Sport, business, famille. Simple et direct.",
    ),
  ];

  int _index = 0;
  bool _showNoMoreOverlay = false;

  // ✅ MATCH POPUP ULTRA DYNAMIQUE
  bool _showMatchOverlay = false;
  late final AnimationController _matchCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  // 🎉 Confettis controller
  late final ConfettiController _confettiCtrl =
  ConfettiController(duration: const Duration(milliseconds: 1400));

  // 🔊 Audio player
  final AudioPlayer _player = AudioPlayer();

  // ✅ Couleur abonnement (jaune doux “bike Bosnie”)
  static const Color _softBikeYellow = Color(0xFFF4C542);

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _confettiCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  String? get _myUid => supabase.auth.currentUser?.id;

  /// Convertit ton currentPlan ("gratuit"/"premium"/"ultra")
  /// vers ce que DailyLimitsRepo attend ("free"/"premium"/"ultra")
  String get _planForLimits {
    final p = currentPlan.toLowerCase().trim();
    if (p == "premium") return "premium";
    if (p == "ultra") return "ultra";
    return "free";
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await supabase.rpc('get_current_plan');
      final p = (plan ?? "gratuit").toString();
      if (!mounted) return;
      setState(() => currentPlan = p.toLowerCase().trim());
    } catch (e) {
      // ignore: avoid_print
      print("get_current_plan error: $e");
    }
  }

  List<_UserCardData> get _filteredUsers {
    final kw = _bioKeyword.trim().toLowerCase();

    return _allUsers.where((u) {
      final okCity = _cityFilter == null || u.city == _cityFilter;

      final okKeyword = kw.isEmpty
          ? true
          : (u.bio.toLowerCase().contains(kw) ||
          u.firstName.toLowerCase().contains(kw) ||
          u.city.toLowerCase().contains(kw));

      return okCity && okKeyword;
    }).toList();
  }

  // -------------------- FILTER SHEET (sans tranche d’âge) --------------------
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        String? tempCity = _cityFilter;
        String tempKw = _bioKeyword;

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
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        )
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
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Mot-clé (bio)",
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
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
                                color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String?>(
                            value: tempCity,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF111827),
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _pillButton(
                                  label: "Réinitialiser",
                                  bg: Colors.white.withOpacity(0.14),
                                  fg: Colors.white,
                                  onTap: () {
                                    setState(() {
                                      _cityFilter = null;
                                      _bioKeyword = "";
                                      _index = 0;
                                      _showNoMoreOverlay = false;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _pillButton(
                                  label: "Appliquer",
                                  bg: const Color(0xFF7C3AED),
                                  fg: Colors.white,
                                  onTap: () {
                                    setState(() {
                                      _cityFilter = tempCity;
                                      _bioKeyword = tempKw;
                                      _index = 0;
                                      _showNoMoreOverlay = false;
                                    });
                                    Navigator.pop(context);
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

  // -------------------- LIMIT POPUP (unique pour swipe/superlike/rewind) --------------------
  Future<void> _showLimitPopup(LimitResult res) async {
    final plan = _planForLimits; // free/premium/ultra

    String featureLabel;
    String body;
    switch (res.action) {
      case LimitAction.rewind:
        featureLabel = "Rewind";
        body = (plan == 'free')
            ? "Rewind : 1/jour en Gratuit.\nPasse Premium (5/jour) ou Ultra (illimité)."
            : "Rewind : limite atteinte.\nPasse Ultra pour illimité.";
        break;
      case LimitAction.superlike:
        featureLabel = "Super Like";
        body = (plan == 'free')
            ? "Super Like : 1/jour en Gratuit.\nPasse Premium (5/jour) ou Ultra (illimité)."
            : "Super Like : limite atteinte.\nPasse Ultra pour illimité.";
        break;
      case LimitAction.swipe:
        featureLabel = "Swipes";
        body = (plan == 'free')
            ? "Swipes : limite quotidienne atteinte.\nPasse Premium/Ultra pour illimité."
            : "Swipes : limite atteinte.\nPasse Ultra pour plus d’avantages.";
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
                Text(
                  "$featureLabel • ${res.used}/${res.limit == 999999 ? '∞' : res.limit}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w800,
                  ),
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
                if (plan == 'free') ...[
                  _upgradeCard(
                    title: "Premium — 2 000 F/mois",
                    subtitle:
                    "Rewind 5/jour • Super Like 5/jour • Swipes illimités",
                    onTap: () => Navigator.pop(context, 'premium'),
                  ),
                  const SizedBox(height: 10),
                ],
                _upgradeCard(
                  title: "Ultra — 5 000 F/mois",
                  subtitle: "Rewind illimité • Mode discret • 2 chances dîner",
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
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                )),
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

  // -------------------- LIMIT ENGINE CALL --------------------

  Future<bool> _consumeOrPopup(LimitAction action) async {
    final uid = _myUid;
    if (uid == null) {
      _toast("Tu dois être connecté.");
      return false;
    }

    try {
      final res = await _limitsRepo.consumeAction(
        userId: uid,
        plan: _planForLimits,
        action: action,
      );

      if (!res.ok) {
        await _showLimitPopup(res);
        return false;
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("consumeAction error: $e");
      _toast("Erreur limites. Vérifie daily_limits.");
      return false;
    }
  }

  /// ✅ SuperLike consomme aussi 1 swipe, SANS perdre une ressource si l’autre est bloquée.
  /// (on pré-vérifie les 2 limites avant de consommer)
  Future<bool> _consumeSuperlikeAndSwipeOrPopup() async {
    final uid = _myUid;
    if (uid == null) {
      _toast("Tu dois être connecté.");
      return false;
    }

    try {
      // 1) Lire la ligne du jour (crée si besoin)
      final today = await _limitsRepo.getOrCreateToday(userId: uid);

      // 2) Limites selon le plan
      final swipeLimit = _limitsRepo.dailyLimitFor(LimitAction.swipe, _planForLimits);
      final superLimit = _limitsRepo.dailyLimitFor(LimitAction.superlike, _planForLimits);

      final swipesUsed = today.swipesCount;
      final superUsed = today.superlikesCount;

      // Illimité -> ok direct (mais on garde le comportement : on avance la carte)
      // (si Ultra/Premium illimité swipe, superlike peut être illimité ou non selon ton repo)
      // Ici : si l’un des deux est limité, on applique le check.
      if (swipeLimit < 999999 && swipesUsed >= swipeLimit) {
        await _showLimitPopup(LimitResult(
          ok: false,
          action: LimitAction.swipe,
          used: swipesUsed,
          limit: swipeLimit,
        ));
        return false;
      }

      if (superLimit < 999999 && superUsed >= superLimit) {
        await _showLimitPopup(LimitResult(
          ok: false,
          action: LimitAction.superlike,
          used: superUsed,
          limit: superLimit,
        ));
        return false;
      }

      // 3) Consommer (superlike + swipe)
      // ordre sans importance puisque on a déjà validé les 2 limites
      await _limitsRepo.consumeAction(
        userId: uid,
        plan: _planForLimits,
        action: LimitAction.superlike,
      );

      await _limitsRepo.consumeAction(
        userId: uid,
        plan: _planForLimits,
        action: LimitAction.swipe,
      );

      return true;
    } catch (e) {
      // ignore: avoid_print
      print("_consumeSuperlikeAndSwipeOrPopup error: $e");
      _toast("Erreur limites (superlike/swipe).");
      return false;
    }
  }

  // -------------------- ACTIONS (avec limites + anti double clic) --------------------

  Future<void> _actionPass() async {
    if (_showNoMoreOverlay) return;
    if (_busySwipe) return;
    _busySwipe = true;

    try {
      final ok = await _consumeOrPopup(LimitAction.swipe);
      if (!ok) return;
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

      // Demo : 1 like sur 3 crée un match
      final isMatch = Random().nextInt(3) == 0;

      if (isMatch) {
        _lastMatchedUser = current;
        await _triggerMatchOverlay();
      }

      _nextCard();
    } finally {
      _busySwipe = false;
    }
  }

  /// ✅ Superlike consomme aussi 1 swipe (avec pré-check pour éviter de “perdre” un superlike)
  Future<void> _actionSuperLike() async {
    if (_showNoMoreOverlay) return;

    if (_busySuperlike) return;
    _busySuperlike = true;

    try {
      final ok = await _consumeSuperlikeAndSwipeOrPopup();
      if (!ok) return;

      // TODO: envoi superlike (Supabase) quand tu branches le backend
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

    // 🔊 son
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/match_pop.mp3'));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    setState(() => _showMatchOverlay = false);
  }

  void _refreshProfiles() {
    setState(() => _showNoMoreOverlay = false);
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
    final users = _filteredUsers;

    final _UserCardData? current = (_showNoMoreOverlay || users.isEmpty)
        ? null
        : users[_index.clamp(0, users.length - 1)];

    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // ✅ Bottom plus compact
    const double navApproxHeight = 68; // réduit
    final double bottomNavBottom = 10 + safeBottom;
    final double actionButtonsBottom = bottomNavBottom + navApproxHeight + 10;

    // ✅ Top bar plus compact
    final topY = 8 + safeTop;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),

          // ✅ TOP GLASS GROUP (Filtre + Logo + Abonnement)
          Positioned(
            top: topY,
            left: 14,
            right: 14,
            child: _glassGroup(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _glassIconButton(
                    icon: Icons.tune_rounded,
                    onTap: _openFilterSheet,
                    size: 52,
                    accent: const Color(0xFF7C3AED),
                  ),
                  const Spacer(),
                  _logoGlassButton(assetPath: "assets/images/logo.png", size: 52),
                  const Spacer(),
                  _glassIconButton(
                    icon: Icons.workspace_premium_rounded,
                    onTap: _goSubscription,
                    size: 52,
                    accent: _softBikeYellow,
                    glow: true,
                  ),
                ],
              ),
            ),
          ),

          // ✅ GROUPE CENTRAL (photo slider + infos) -> prend beaucoup de place
          Positioned(
            top: topY + 72,
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
              ),
            ),
          ),

          // ✅ ACTION BUTTONS GROUP (oval)
          Positioned(
            left: 14,
            right: 14,
            bottom: actionButtonsBottom,
            child: _glassGroup(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                    onTap: () => _actionPass(),
                    size: 58,
                  ),
                  _roundActionModern(
                    icon: Icons.star_rounded,
                    bg: const Color(0xFF1E88E5),
                    onTap: () => _actionSuperLike(),
                    size: 58,
                  ),
                  _roundActionModern(
                    icon: Icons.favorite_rounded,
                    bg: const Color(0xFF43A047),
                    onTap: () => _actionLike(),
                    size: 58,
                  ),
                ],
              ),
            ),
          ),

          // ✅ BOTTOM NAV (oval + plus petit)
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomNavBottom,
            child: _glassGroup(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navIconBadge(
                    icon: Icons.chat_bubble_outline,
                    badgeCount: unreadMatches,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchesScreen()),
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

          // NO MORE
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

          // ✅ MATCH POPUP
          if (_showMatchOverlay)
            Positioned.fill(
              child: _MatchCelebrationOverlay(
                controller: _matchCtrl,
                confettiController: _confettiCtrl,
                myImagePath: "assets/images/logo.png",
                matchImagePath: _lastMatchedUser?.images.isNotEmpty == true
                    ? _lastMatchedUser!.images.first
                    : "assets/images/sample_profile_1.jpg",
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

// -------------------- BIG PROFILE CARD (slider + infos) --------------------

class _ProfileCardBig extends StatefulWidget {
  final _UserCardData? user;
  final String emptyText;
  final bool showNoMore;

  const _ProfileCardBig({
    required this.user,
    required this.emptyText,
    required this.showNoMore,
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

    if (widget.showNoMore) {
      return Center(
        child: Text(
          widget.emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      );
    }

    if (u == null) {
      return Center(
        child: Text(
          widget.emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Column(
      children: [
        // PHOTO SLIDER (gros)
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
                      if (path == null) {
                        return Container(
                          color: Colors.white.withOpacity(0.06),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                size: 44, color: Colors.white70),
                          ),
                        );
                      }
                      return Image.asset(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.06),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                size: 44, color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Dots si plusieurs photos
                if (u.images.length > 1)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _photoDots(count: u.images.length, active: _photoIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // INFOS PROFIL (vérifié + prénom + âge + bio)
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
            const SizedBox(width: 10),
            _miniVerifiedBadge(isVerified: u.isVerified),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Colors.white70, size: 18),
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
            color: Colors.black.withOpacity(0.25),
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
}

// -------------------- UI HELPERS --------------------

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
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
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
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: glow
                ? [
              BoxShadow(
                color: (accent ?? Colors.white).withOpacity(0.22),
                blurRadius: 16,
                spreadRadius: 1,
              )
            ]
                : null,
          ),
          child: Icon(icon, color: accent ?? Colors.white, size: 30),
        ),
      ),
    ),
  );
}

Widget _logoGlassButton({required String assetPath, double size = 56}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.all(8),
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
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    ),
  );
}

/// Bottom nav compact (oval group) : icônes + badges (sans texte pour gagner de la place)
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
            border: Border.all(color: Colors.white.withOpacity(0.18)),
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

Widget _miniVerifiedBadge({required bool isVerified}) {
  final txt = isVerified ? "Profil vérifié" : "Non vérifié";
  final icon = isVerified ? Icons.verified_rounded : Icons.info_outline_rounded;
  final color = isVerified ? const Color(0xFF00E676) : Colors.white;

  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              txt,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
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

// -------------------- OVERLAYS --------------------

class _NoMoreProfilesOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _NoMoreProfilesOverlay({
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
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
                        "Reviens dans quelques heures.\nTu peux aussi rafraîchir.",
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
                          onPressed: onRefresh,
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
    final scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    final heartBounce = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
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
              emissionFrequency: 0.12,
              numberOfParticles: 30,
              gravity: 0.25,
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: min(MediaQuery.of(context).size.width - 32, 420),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE63946).withOpacity(0.28),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "🔥 C’EST UN MATCH !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 92,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(left: 80, child: _roundPhoto(matchImagePath)),
                                Positioned(left: 28, child: _roundPhoto(myImagePath)),
                                ScaleTransition(
                                  scale: heartBounce,
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE63946),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 10),
                                        )
                                      ],
                                    ),
                                    child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Toi + $matchName 💜\nEnvoyez-vous un message maintenant !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.25,
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
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipOval(
        child: Image.asset(
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

// -------------------- MODEL --------------------

class _UserCardData {
  final String firstName;
  final int age;
  final String city;
  final bool isVerified;
  final List<String> images;
  final String bio;

  const _UserCardData({
    required this.firstName,
    required this.age,
    required this.city,
    required this.isVerified,
    required this.images,
    required this.bio,
  });
}