import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

enum PlanType { free, premium, ultra }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    _enableScreenshotBlock();
  }

  Future<void> _enableScreenshotBlock() async {
    // Android: bloque screenshots/recording via FLAG_SECURE
    // iOS: pas de blocage parfait natif (on gèrera plus tard si tu veux)
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }

  @override
  void dispose() {
    // Optionnel: tu peux laisser FLAG_SECURE actif app-wide.
    super.dispose();
  }

  void _onSubscribe(PlanType plan) {
    // Pour l’instant: on garde un stub.
    // Étape suivante: brancher PayDunya (checkout + callback + activation premium)
    final label = switch (plan) {
      PlanType.free => "Gratuit",
      PlanType.premium => "Premium",
      PlanType.ultra => "Ultra",
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Choix: $label — on branche PayDunya juste après ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE63946);
    const premiumGold = Color(0xFFD4AF37);
    const ultraPurple = Color(0xFF6D28D9);
    const softGray = Color(0xFFF5F5F5);

    final plans = <_PlanCardData>[
      _PlanCardData(
        type: PlanType.free,
        title: "Gratuit",
        headerColor: Colors.green,
        priceText: "0 F / mois",
        buttonColor: primaryRed,
        features: const [
          "20 likes / jour",
          "1 Super Like / jour",
          "Accès à tous les filtres",
          "Chat après match uniquement",
          "Blocage des captures d’écrans",
        ],
      ),
      _PlanCardData(
        type: PlanType.premium,
        title: "Premium",
        headerColor: premiumGold,
        priceText: "2 000 F / mois",
        buttonColor: primaryRed,
        features: const [
          "Swipes illimités",
          "5 Super Likes / jour",
          "Filtres",
          "Chat après match uniquement",
          "Voir qui m’a liké",
          "1 chance au tirage “Cadeau du mois” (30 000 CFA)",
          "Blocage des captures d’écrans",
        ],
      ),
      _PlanCardData(
        type: PlanType.ultra,
        title: "Ultra",
        headerColor: ultraPurple,
        priceText: "5 000 F / mois",
        buttonColor: primaryRed,
        features: const [
          "Tout Premium",
          "Super Likes illimités",
          "Mode discret (bloquer des profils via numéros de téléphone)",
          "2 chances au tirage “Cadeau du mois” (30 000 CFA)",
          "Blocage des captures d’écrans",
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Column(
          children: const [
            SizedBox(height: 2),
            Text("FasoMatch", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: softGray,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "Choisis ton abonnement FasoMatch",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),

                // CARTES (3 colonnes sur grand écran, sinon vertical)
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < plans.length; i++) ...[
                        Expanded(child: _PlanCard(data: plans[i], onSubscribe: _onSubscribe)),
                        if (i != plans.length - 1) const SizedBox(width: 14),
                      ],
                    ],
                  )
                else
                  Column(
                    children: [
                      for (final p in plans) ...[
                        _PlanCard(data: p, onSubscribe: _onSubscribe),
                        const SizedBox(height: 14),
                      ]
                    ],
                  ),

                const SizedBox(height: 10),
                const Text("Paiement via", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _PaymentLogo(path: "assets/payments/orange_money.png", label: "Orange Money"),
                    _PaymentLogo(path: "assets/payments/moov_money.png", label: "Moov Money"),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCardData {
  final PlanType type;
  final String title;
  final Color headerColor;
  final String priceText;
  final Color buttonColor;
  final List<String> features;

  _PlanCardData({
    required this.type,
    required this.title,
    required this.headerColor,
    required this.priceText,
    required this.buttonColor,
    required this.features,
  });
}

class _PlanCard extends StatelessWidget {
  final _PlanCardData data;
  final void Function(PlanType) onSubscribe;

  const _PlanCard({required this.data, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    const borderGray = Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGray),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // titre
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: data.headerColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                data.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("Avantages :", style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          ...data.features.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("•  ", style: TextStyle(fontSize: 16, height: 1.25)),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 14, height: 1.25))),
              ],
            ),
          )),

          const SizedBox(height: 10),
          Text(
            data.priceText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: data.buttonColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () => onSubscribe(data.type),
              child: const Text("S’abonner", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentLogo extends StatelessWidget {
  final String path;
  final String label;

  const _PaymentLogo({required this.path, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(10),
          child: Image.asset(path, fit: BoxFit.contain),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}