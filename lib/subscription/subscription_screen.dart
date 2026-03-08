import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import '../ui/app_logo.dart';
import '../ui/app_colors.dart';

enum PlanType { free, premium, ultra }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  PlanType _currentPlan = PlanType.free;
  bool _loadingPlan = true;
  Timer? _paymentPollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableScreenshotBlock();
    _loadCurrentPlan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentPollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCurrentPlan();
    }
  }

  Future<void> _enableScreenshotBlock() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }

  PlanType _parsePlan(String plan) {
    switch (plan) {
      case 'premium':
        return PlanType.premium;
      case 'ultra':
        return PlanType.ultra;
      default:
        return PlanType.free;
    }
  }

  String _planLabel(PlanType p) {
    switch (p) {
      case PlanType.premium:
        return "Premium";
      case PlanType.ultra:
        return "Ultra";
      default:
        return "Gratuit";
    }
  }

  Future<void> _loadCurrentPlan() async {
    if (mounted) {
      setState(() => _loadingPlan = true);
    }

    try {
      final client = Supabase.instance.client;

      final res = await client.rpc('get_current_plan');

      final row = (res as List).isNotEmpty ? res.first : null;

      if (row == null) throw Exception("No plan");

      final planStr = (row['plan'] ?? 'free').toString().toLowerCase();

      final plan = _parsePlan(planStr);

      if (!mounted) return;

      setState(() {
        _currentPlan = plan;
        _loadingPlan = false;
      });
    } catch (e) {
      debugPrint("get_current_plan error: $e");

      if (!mounted) return;

      setState(() {
        _currentPlan = PlanType.free;
        _loadingPlan = false;
      });
    }
  }

  Future<void> _startPayDunyaCheckout(PlanType plan) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final amount = plan == PlanType.premium ? 2000 : 5000;

    try {
      _showLoader("Préparation du paiement...");

      final res = await client.functions.invoke(
        'paydunya-create-invoice',
        body: {
          "plan": plan.name,
          "amount": amount,
          "user_id": user.id,
        },
      );

      Navigator.pop(context);

      final url = res.data["checkout_url"];

      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);

      _startPaymentPolling(plan);
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur paiement : $e")));
    }
  }

  void _startPaymentPolling(PlanType plan) {
    _paymentPollingTimer?.cancel();

    _showLoader("Vérification du paiement...");

    int attempts = 0;

    _paymentPollingTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          attempts++;

          await Supabase.instance.client.auth.refreshSession();

          await _loadCurrentPlan();

          if (_currentPlan == plan) {
            timer.cancel();
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Abonnement ${_planLabel(plan)} activé")));

            return;
          }

          if (attempts > 36) {
            timer.cancel();
            Navigator.pop(context);
          }
        });
  }

  void _showLoader(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 90),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(text)
            ],
          ),
        ),
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required List<String> features,
    required PlanType type,
  }) {
    final isCurrent = type == _currentPlan;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...features.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text("• $e"),
          )),
          const SizedBox(height: 10),
          Text(price,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.black : Colors.red,
              ),
              onPressed: () => _startPayDunyaCheckout(type),
              child: Text(
                  isCurrent ? "Rester ${_planLabel(type)}" : "S'abonner"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const AppLogo(size: 75),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Choisis ton abonnement FasoMatch",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/orange_money sample.png", height: 75),
                const SizedBox(width: 75),
                Image.asset("assets/images/moov_money sample.png", height: 75),
              ],
            ),
            const SizedBox(height: 75),
            _planCard(
              title: "Gratuit",
              price: "0 F / mois",
              type: PlanType.free,
              features: const [
                "20 likes / jour",
                "1 Super Like / jour",
                "1 retour / jour",
                "Blocage capture écran",
              ],
            ),

            _planCard(
              title: "Premium",
              price: "2 000 F / mois",
              type: PlanType.premium,
              features: const [
                "Swipes illimités",
                "5 Super Likes",
                "5 retours",
                "Blocage capture écran",
                "Voir qui t’a liké",
                "1 chance tirage cadeau du mois (valeur 30 000 CFA)"
              ],
            ),

            _planCard(
              title: "Ultra",
              price: "5 000 F / mois",
              type: PlanType.ultra,
              features: const [
                "Tout Premium",
                "Super Likes illimités",
                "Retours illimités",
                "Blocage capture écran",
                "Mode discret",
                "2 chances tirage cadeau du mois (valeur 30 000 CFA)"
              ],
            ),
          ],
        ),
      ),
    );
  }
}