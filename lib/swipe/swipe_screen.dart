import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../match/matches_screen.dart';
import '../likes/likes_received_screen.dart';
import '../discreet/discreet_mode_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // ✅ Plan courant (gratuit / premium / ultra)
  String currentPlan = "gratuit";

  // ---- FILTRES ----
  String? _cityFilter; // null = toutes
  RangeValues _ageRange = const RangeValues(18, 35);
  String _bioKeyword = ""; // filtre par mot clé (bio)

  // ✅ Compteurs (badges) (à remplacer par vraies requêtes Supabase)
  int unreadLikes = 17;
  int unreadMatches = 2;

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

  // ✅ Animation match overlay
  bool _showMatchOverlay = false;
  late final AnimationController _matchCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    try {
      // ✅ demandé par toi
      final plan = await supabase.rpc('get_current_plan');
      // ignore: avoid_print
      print(plan);

      final p = (plan ?? "gratuit").toString();
      if (!mounted) return;
      setState(() => currentPlan = p);
    } catch (e) {
      // ignore: avoid_print
      print("get_current_plan error: $e");
    }
  }

  List<_UserCardData> get _filteredUsers {
    final kw = _bioKeyword.trim().toLowerCase();

    return _allUsers.where((u) {
      final okCity = _cityFilter == null || u.city == _cityFilter;
      final okAge =
          u.age >= _ageRange.start.round() && u.age <= _ageRange.end.round();

      final okKeyword = kw.isEmpty
          ? true
          : (u.bio.toLowerCase().contains(kw) ||
          u.firstName.toLowerCase().contains(kw) ||
          u.city.toLowerCase().contains(kw));

      return okCity && okAge && okKeyword;
    }).toList();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        String? tempCity = _cityFilter;
        RangeValues tempAge = _ageRange;
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

                          // Mot clé bio
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
                            decoration: _modernInputDeco(
                              "Ex: sérieux, sport, voyage...",
                            ),
                            onChanged: (v) => setLocal(() => tempKw = v),
                          ),

                          const SizedBox(height: 14),

                          // Ville
                          const Text(
                            "Ville",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
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
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text("Toutes les villes"),
                              ),
                              ..._cities.map(
                                    (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              ),
                            ],
                            onChanged: (v) => setLocal(() => tempCity = v),
                          ),

                          const SizedBox(height: 16),

                          // Age
                          Text(
                            "Tranche d’âge : ${tempAge.start.round()} - ${tempAge.end.round()}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF7C3AED),
                              thumbColor: const Color(0xFF7C3AED),
                              inactiveTrackColor: Colors.white.withOpacity(0.20),
                            ),
                            child: RangeSlider(
                              values: tempAge,
                              min: 18,
                              max: 60,
                              divisions: 42,
                              labels: RangeLabels(
                                tempAge.start.round().toString(),
                                tempAge.end.round().toString(),
                              ),
                              onChanged: (v) => setLocal(() => tempAge = v),
                            ),
                          ),

                          const SizedBox(height: 14),

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
                                      _ageRange = const RangeValues(18, 35);
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
                                      _ageRange = tempAge;
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

  void _goSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(
          currentPlan: currentPlan,
          onPlanSelected: (p) => setState(() => currentPlan = p),
        ),
      ),
    );
  }

  void _actionPass() => _nextCard();

  void _actionSuperLike() {
    // TODO: brancher superlike Supabase
    _nextCard();
  }

  void _actionRewind() {
    final users = _filteredUsers;
    if (users.isEmpty) return;
    if (_index > 0) setState(() => _index -= 1);
  }

  void _actionLike() {
    // TODO: brancher like Supabase + logique match réelle
    // Demo : 1 like sur 3 crée un match
    final isMatch = Random().nextInt(3) == 0;
    if (isMatch) {
      _triggerMatchOverlay();
      // TODO notifications:
      // - si app ouverte -> overlay (ok)
      // - si app fermée -> push (Firebase) ou local notification
    } else {
      // TODO: si app fermée -> notification like
    }

    _nextCard();
  }

  void _triggerMatchOverlay() async {
    if (!mounted) return;
    setState(() => _showMatchOverlay = true);
    _matchCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1200));
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

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    final _UserCardData? current = (_showNoMoreOverlay || users.isEmpty)
        ? null
        : users[_index.clamp(0, users.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ FULL SCREEN CARD (plus de bords noirs)
          Positioned.fill(
            child: _ProfileCardFullScreen(
              user: current,
              emptyText: "Aucun profil pour le moment.\nReviens plus tard 🙂",
              showNoMore: _showNoMoreOverlay,
              // ✅ on remonte le texte au-dessus du groupe de boutons
              bottomTextSafeArea: 230, // important
            ),
          ),

          // ✅ TOP BAR (style modèle)
          Positioned(
            top: 14 + MediaQuery.of(context).padding.top,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _glassIconButton(
                  icon: Icons.tune_rounded,
                  onTap: _openFilterSheet,
                  size: 56,
                  accent: const Color(0xFF7C3AED), // violet
                ),
                const Spacer(),
                Image.asset(
                  "assets/images/logo.png",
                  width: 120,
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                _glassIconButton(
                  icon: Icons.workspace_premium_rounded,
                  onTap: _goSubscription,
                  size: 56,
                  accent: const Color(0xFFFFC107),
                  glow: true,
                ),
              ],
            ),
          ),

          // ✅ ACTION BUTTONS GROUP (un seul groupe comme modèle)
          Positioned(
            left: 14,
            right: 14,
            bottom: 98, // au-dessus du nav
            child: _glassGroup(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundActionModern(
                    icon: Icons.undo_rounded,
                    bg: const Color(0xFFFB8C00),
                    onTap: _actionRewind,
                    size: 66,
                  ),
                  _roundActionModern(
                    icon: Icons.close_rounded,
                    bg: const Color(0xFFE53935),
                    onTap: _actionPass,
                    size: 66,
                  ),
                  _roundActionModern(
                    icon: Icons.star_rounded,
                    bg: const Color(0xFF1E88E5),
                    onTap: _actionSuperLike,
                    size: 66,
                  ),
                  _roundActionModern(
                    icon: Icons.favorite_rounded,
                    bg: const Color(0xFF43A047),
                    onTap: _actionLike,
                    size: 66,
                  ),
                ],
              ),
            ),
          ),

          // ✅ BOTTOM NAV (NE PAS MODIFIER TES BOUTONS)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14 + MediaQuery.of(context).padding.bottom,
            child: _glassGroup(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navCircleWithBadge(
                    icon: Icons.chat_bubble_outline,
                    label: "Match",
                    size: 66,
                    badgeCount: unreadMatches,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchesScreen()),
                      );
                    },
                  ),
                  _navCircleWithBadge(
                    icon: Icons.visibility_off_outlined,
                    label: "Masquer",
                    size: 66,
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
                  _navCircleWithBadge(
                    icon: Icons.favorite_border,
                    label: "Likes",
                    size: 66,
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
                  _navCircleWithBadge(
                    icon: Icons.person_outline,
                    label: "Profil",
                    size: 66,
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

          // ✅ NO MORE OVERLAY
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

          // ✅ MATCH ANIMATION (ultra fun)
          if (_showMatchOverlay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: _MatchOverlay(controller: _matchCtrl),
              ),
            ),
        ],
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
                color: (accent ?? Colors.white).withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 2,
              )
            ]
                : null,
          ),
          child: Icon(
            icon,
            color: accent ?? Colors.white,
            size: 30,
          ),
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

Widget _navCircleWithBadge({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  int badgeCount = 0,
  double size = 66,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: SizedBox(
      width: size + 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(22),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          )
        ],
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
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
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
                          color: Colors.white.withOpacity(0.75),
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

class _MatchOverlay extends StatelessWidget {
  final AnimationController controller;

  const _MatchOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    return Material(
      color: Colors.black.withOpacity(0.55),
      child: Center(
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.28),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "💜 MATCH !",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Vous vous êtes likés 🎉\nEnvoie un message maintenant !",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () {
                            // TODO: ouvrir chat direct sur le match
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Envoyer un message",
                            style: TextStyle(fontWeight: FontWeight.w900),
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
    );
  }
}

// -------------------- CARD FULLSCREEN (photos + dots + texte safe) --------------------

class _ProfileCardFullScreen extends StatefulWidget {
  final _UserCardData? user;
  final String emptyText;
  final bool showNoMore;
  final double bottomTextSafeArea;

  const _ProfileCardFullScreen({
    required this.user,
    required this.emptyText,
    required this.showNoMore,
    required this.bottomTextSafeArea,
  });

  @override
  State<_ProfileCardFullScreen> createState() => _ProfileCardFullScreenState();
}

class _ProfileCardFullScreenState extends State<_ProfileCardFullScreen> {
  final PageController _pageCtrl = PageController();
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant _ProfileCardFullScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _photoIndex = 0;
      _pageCtrl.jumpToPage(0);
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
      return Container(color: Colors.black);
    }

    if (u == null) {
      return Container(
        alignment: Alignment.center,
        color: Colors.black,
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

    return Stack(
      children: [
        // ✅ Photos fullscreen (PageView)
        Positioned.fill(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: u.images.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (_, i) {
              return Image.asset(
                u.images[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 44),
                  ),
                ),
              );
            },
          ),
        ),

        // ✅ Gradient bas (pour le texte)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: max(260, widget.bottomTextSafeArea + 80),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.82),
                ],
              ),
            ),
          ),
        ),

        // ✅ Dots (pile de photos)
        if (u.images.length > 1)
          Positioned(
            top: 86 + MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Center(
              child: _photoDots(
                count: u.images.length,
                active: _photoIndex,
              ),
            ),
          ),

        // ✅ Badge Profil vérifié uniquement (pas d'actif)
        Positioned(
          left: 14,
          top: 86 + MediaQuery.of(context).padding.top,
          child: _pillBadge(
            text: u.isVerified ? "Profil vérifié" : "Non vérifié",
            icon: u.isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
            iconColor: u.isVerified ? const Color(0xFF00E676) : Colors.white,
          ),
        ),

        // ✅ Infos (remontées au-dessus du groupe boutons)
        Positioned(
          left: 16,
          right: 16,
          bottom: widget.bottomTextSafeArea,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${u.firstName}  ${u.age}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    u.city,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (u.bio.trim().isNotEmpty)
                Text(
                  u.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
            ],
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
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(count, (i) {
              final on = i == active;
              return Container(
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

  Widget _pillBadge({
    required String text,
    required IconData icon,
    required Color iconColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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

  // ✅ multi photos
  final List<String> images;

  // ✅ filtre mot-clé
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