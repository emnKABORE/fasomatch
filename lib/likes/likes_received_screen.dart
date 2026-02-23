import 'dart:ui';
import 'package:flutter/material.dart';

class LikesReceivedScreen extends StatelessWidget {
  /// "gratuit" / "premium" / "ultra"
  final String currentPlan;

  /// Action quand on clique "Voir les abonnements"
  final VoidCallback? onUpgradeTap;

  const LikesReceivedScreen({
    super.key,
    this.currentPlan = "gratuit",
    this.onUpgradeTap,
  });

  bool get _canAccess => currentPlan == "premium" || currentPlan == "ultra";

  @override
  Widget build(BuildContext context) {
    final fakeLikes = const ["Aïcha", "Nina", "Moussa", "Sara"];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        title: const Text(
          "Likes reçus",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: fakeLikes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final name = fakeLikes[i];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _canAccess
                    ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Ouvrir profil de $name (à brancher)")),
                  );
                }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black12,
                        child: Text(
                          name.characters.first,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          ),

          if (!_canAccess)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withOpacity(0.65),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "🔒 Réservé Premium & Ultra",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Passe en Premium pour voir tes likes et répondre.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              onPressed: onUpgradeTap ??
                                      () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Page abonnements à brancher"),
                                      ),
                                    );
                                  },
                              child: const Text(
                                "Voir les abonnements",
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
        ],
      ),
    );
  }
}