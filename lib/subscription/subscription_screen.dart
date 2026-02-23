import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  final String currentPlan;
  final void Function(String plan) onPlanSelected;

  const SubscriptionScreen({
    super.key,
    required this.currentPlan,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        title: const Text("Abonnements",
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _planCard(context, "gratuit", "Gratuit", "Fonctions de base"),
            const SizedBox(height: 10),
            _planCard(context, "premium", "Premium", "Voir les likes reçus"),
            const SizedBox(height: 10),
            _planCard(context, "ultra", "Ultra", "Mode discret + tout Premium"),
          ],
        ),
      ),
    );
  }

  Widget _planCard(
      BuildContext context, String key, String title, String desc) {
    final selected = currentPlan == key;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? const Color(0xFF1E2DFF) : Colors.black12, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              onPlanSelected(key);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2DFF),
              foregroundColor: Colors.white,
            ),
            child: const Text("Choisir"),
          )
        ],
      ),
    );
  }
}