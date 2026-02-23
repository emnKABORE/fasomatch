import 'dart:ui';
import 'package:flutter/material.dart';

enum UserPlan { free, premium, ultra }

class PlanService {
  // ✅ TEMP: remplace ensuite par Supabase (abonnements table)
  static UserPlan currentPlan = UserPlan.free;

  static bool isPremiumOrUltra() =>
      currentPlan == UserPlan.premium || currentPlan == UserPlan.ultra;

  static bool isUltra() => currentPlan == UserPlan.ultra;

  static String label() {
    switch (currentPlan) {
      case UserPlan.free:
        return "Gratuit";
      case UserPlan.premium:
        return "Premium";
      case UserPlan.ultra:
        return "Ultra Premium";
    }
  }
}

/// ✅ Paywall flou réutilisable (Premium/Ultra)
class PaywallBlur extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onUpgradeTap;

  const PaywallBlur({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.white.withOpacity(0.55),
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE63946),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: onUpgradeTap,
                          child: Text(
                            buttonText,
                            style: const TextStyle(fontWeight: FontWeight.w900),
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