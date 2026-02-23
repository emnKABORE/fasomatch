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

class _SwipeScreenState extends State<SwipeScreen> {
  final supabase = Supabase.instance.client;

  // ✅ Plus tard tu le récupères depuis Supabase (abonnements table)
  // Pour l’instant : "gratuit" / "premium" / "ultra"
  String currentPlan = "gratuit";

  // ---- UI SIZES (STANDARD) ----
  static const double kActionBtn = 72; // Like / Pass / Star / Rewind
  static const double kTopBtn = 72; // Filtre / Premium
  static const double kTopRadius = 22;
  static const double kActionGap = 16;
  static const double kCardMaxWidth = 420; // largeur max sur web

  // ---- FILTRES ----
  String? _cityFilter; // null = toutes
  RangeValues _ageRange = const RangeValues(18, 35);

  final List<String> _cities = const [
    "Ouagadougou",
    "Bobo-Dioulasso",
    "Koudougou",
    "Fada N'Gourma",
    "Banfora",
  ];

  // ---- DONNÉES FAKE (on branchera Supabase après) ----
  final List<_UserCardData> _allUsers = [
    _UserCardData(
      firstName: "Aïcha",
      age: 24,
      city: "Ouagadougou",
      isVerified: true,
      imageAsset: "assets/images/sample_profile_1.jpg",
    ),
    _UserCardData(
      firstName: "Nina",
      age: 22,
      city: "Bobo-Dioulasso",
      isVerified: false,
      imageAsset: "assets/images/sample_profile_2.jpg",
    ),
    _UserCardData(
      firstName: "Moussa",
      age: 29,
      city: "Ouagadougou",
      isVerified: true,
      imageAsset: "assets/images/sample_profile_3.jpg",
    ),
  ];

  int _index = 0;

  // ✅ Overlay "plus de profils" (fermable)
  bool _showNoMoreOverlay = false;

  List<_UserCardData> get _filteredUsers {
    return _allUsers.where((u) {
      final okCity = _cityFilter == null || u.city == _cityFilter;
      final okAge =
          u.age >= _ageRange.start.round() && u.age <= _ageRange.end.round();
      return okCity && okAge;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      // ✅ demandé : rpc + print
      final plan = await supabase.rpc('get_current_plan');
      // ignore: avoid_print
      print(plan);

      // ✅ si la RPC renvoie "gratuit"/"premium"/"ultra"
      if (plan is String && mounted) {
        setState(() => currentPlan = plan);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Erreur get_current_plan: $e");
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        String? tempCity = _cityFilter;
        RangeValues tempAge = _ageRange;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Filtres",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  const Text("Ville",
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: tempCity,
                    isExpanded: true,
                    decoration: _ovalInputDeco("Toutes les villes"),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("Toutes les villes"),
                      ),
                      ..._cities.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => tempCity = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tranche d’âge : ${tempAge.start.round()} - ${tempAge.end.round()}",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  RangeSlider(
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _cityFilter = null;
                                _ageRange = const RangeValues(18, 35);
                                _index = 0;
                                _showNoMoreOverlay = false;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Réinitialiser",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2DFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _cityFilter = tempCity;
                                _ageRange = tempAge;
                                _index = 0;
                                _showNoMoreOverlay = false;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Appliquer",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
  void _actionLike() => _nextCard();
  void _actionSuperLike() => _nextCard();

  void _actionRewind() {
    final users = _filteredUsers;
    if (users.isEmpty) return;
    if (_index > 0) {
      setState(() => _index -= 1);
    }
  }

  void _refreshProfiles() {
    // Plus tard : refetch Supabase
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

    // ✅ si overlay actif => zone blanche
    final _UserCardData? current =
    (_showNoMoreOverlay || users.isEmpty) ? null : users[_index.clamp(0, users.length - 1)];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP BAR ---
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  _topIconButton(
                    icon: Icons.filter_alt_rounded,
                    bg: const Color(0xFF6D28D9),
                    onTap: _openFilterSheet,
                    size: kTopBtn,
                    iconSize: 34,
                    radius: kTopRadius,
                  ),
                  const Spacer(),

                  Image.asset(
                    "assets/images/logo.png",
                    width: 130,
                    height: 90,
                    fit: BoxFit.contain,
                  ),

                  const Spacer(),

                  _topIconButton(
                    icon: Icons.workspace_premium_rounded,
                    bg: const Color(0xFFFFC107),
                    onTap: _goSubscription,
                    size: kTopBtn,
                    iconSize: 34,
                    radius: kTopRadius,
                  ),
                ],
              ),
            ),

            // --- CARD AREA + overlay non bloquant ---
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kCardMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      children: [
                        _ProfileCard(
                          user: current,
                          emptyText: "Aucun profil pour le moment.\nReviens plus tard 🙂",
                          forceWhiteEmpty: _showNoMoreOverlay,
                        ),

                        // ✅ overlay NON BLOQUANT : fond ignore les taps
                        if (_showNoMoreOverlay)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: Container(color: Colors.transparent),
                            ),
                          ),

                        // ✅ seule la carte du popup est cliquable
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
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- ACTION BUTTONS GROUP (rectangle translucide) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _roundAction(
                      icon: Icons.undo_rounded,
                      bg: const Color(0xFFFB8C00),
                      onTap: _actionRewind,
                      size: kActionBtn,
                    ),
                    const SizedBox(width: kActionGap),
                    _roundAction(
                      icon: Icons.close_rounded,
                      bg: const Color(0xFFE53935),
                      onTap: _actionPass,
                      size: kActionBtn,
                    ),
                    const SizedBox(width: kActionGap),
                    _roundAction(
                      icon: Icons.star_rounded,
                      bg: const Color(0xFF1E88E5),
                      onTap: _actionSuperLike,
                      size: kActionBtn,
                    ),
                    const SizedBox(width: kActionGap),
                    _roundAction(
                      icon: Icons.favorite_rounded,
                      bg: const Color(0xFF43A047),
                      onTap: _actionLike,
                      size: kActionBtn,
                    ),
                  ],
                ),
              ),
            ),

            // --- BOTTOM NAV GROUP (rect translucide) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.60),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navIcon(
                      icon: Icons.chat_bubble_outline,
                      label: "Match",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MatchesScreen()),
                        );
                      },
                    ),
                    _navIcon(
                      icon: Icons.visibility_off_outlined,
                      label: "Masquer",
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
                    _navIcon(
                      icon: Icons.favorite_border,
                      label: "Likes",
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
                    _navIcon(
                      icon: Icons.person_outline,
                      label: "Profil",
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
          ],
        ),
      ),
    );
  }
}

// -------------------- UI --------------------

InputDecoration _ovalInputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.85),
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
      borderSide: const BorderSide(color: Color(0xFF1E2DFF), width: 1.4),
    ),
  );
}

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
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Reviens dans quelques heures.\nTu peux aussi rafraîchir.",
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
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                icon: const Icon(Icons.close_rounded),
                tooltip: "Fermer",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final _UserCardData? user;
  final String emptyText;
  final bool forceWhiteEmpty;

  const _ProfileCard({
    required this.user,
    required this.emptyText,
    this.forceWhiteEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    if (forceWhiteEmpty) {
      return Container(
        height: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
        ),
      );
    }

    if (user == null) {
      return Container(
        height: 520,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                user!.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 40),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user!.isVerified ? Icons.verified_rounded : Icons.info_outline,
                      color: user!.isVerified ? const Color(0xFF00E676) : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user!.isVerified ? "Profil vérifié" : "Non vérifié",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
                child: Text(
                  "${user!.firstName}, ${user!.age} ans\n${user!.city}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _topIconButton({
  required IconData icon,
  required Color bg,
  required VoidCallback onTap,
  double size = 44,
  double iconSize = 22,
  double radius = 16,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(radius),
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    ),
  );
}

Widget _roundAction({
  required IconData icon,
  required Color bg,
  required VoidCallback onTap,
  double size = 56,
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
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    ),
  );
}

Widget _navIcon({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  double width = 78,
  double height = 56,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: Colors.black87),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

// -------------------- MODEL --------------------

class _UserCardData {
  final String firstName;
  final int age;
  final String city;
  final bool isVerified;
  final String imageAsset;

  const _UserCardData({
    required this.firstName,
    required this.age,
    required this.city,
    required this.isVerified,
    required this.imageAsset,
  });
}