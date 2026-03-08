import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscreetModeScreen extends StatefulWidget {
  final String currentPlan; // free / premium / ultra
  final VoidCallback onUpgradeTap;

  const DiscreetModeScreen({
    super.key,
    required this.currentPlan,
    required this.onUpgradeTap,
  });

  @override
  State<DiscreetModeScreen> createState() => _DiscreetModeScreenState();
}

class _DiscreetModeScreenState extends State<DiscreetModeScreen> {
  final _phoneCtrl = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> blockedPhones = [];

  bool get _canAdd => widget.currentPlan == "ultra";

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_refreshTypingStyle);
    _loadBlockedPhones();
  }

  void _refreshTypingStyle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_refreshTypingStyle);
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _askUpgrade() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🔒 Ajout réservé à Ultra"),
        content: const Text(
          "Tu peux consulter et supprimer les numéros déjà bloqués, "
              "mais l’ajout de nouveaux numéros est réservé aux abonnés Ultra.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onUpgradeTap();
            },
            child: const Text("Passer Ultra"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBlockedPhones() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          blockedPhones = [];
          _loading = false;
        });
        return;
      }

      final res = await _supabase
          .from('discreet_blocks')
          .select('id, blocked_phone_e164, created_at')
          .eq('owner_user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        blockedPhones = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast("Erreur chargement : $e");
    }
  }

  Future<void> _addPhone() async {
    if (!_canAdd) {
      _askUpgrade();
      return;
    }

    final t = _phoneCtrl.text.trim();
    if (t.isEmpty) return;

    setState(() => _saving = true);

    try {
      final res = await _supabase.rpc(
        'add_discreet_block',
        params: {'p_phone': t},
      );

      final data = Map<String, dynamic>.from(res as Map);

      if (data['ok'] == true) {
        try {
          await HapticFeedback.lightImpact();
        } catch (_) {}

        _phoneCtrl.clear();
        await _loadBlockedPhones();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Numéro bloqué avec succès"),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      } else {
        final err = (data['error'] ?? 'Erreur inconnue').toString();
        if (err == 'ultra_required') {
          _askUpgrade();
        } else if (err == 'invalid_phone') {
          _toast("Numéro invalide");
        } else {
          _toast("Erreur : $err");
        }
      }
    } catch (e) {
      _toast("Erreur ajout : $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhone(String blockId) async {
    try {
      final res = await _supabase.rpc(
        'remove_discreet_block',
        params: {'p_block_id': blockId},
      );

      final data = Map<String, dynamic>.from(res as Map);

      if (data['ok'] == true) {
        await _loadBlockedPhones();
        _toast("Numéro supprimé");
      } else {
        _toast("Suppression impossible");
      }
    } catch (e) {
      _toast("Erreur suppression : $e");
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 120,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/logo.png",
              height: 75,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 75,
                child: Center(
                  child: Text(
                    "FasoMatch",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Mode discret",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bloquer par numéro",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          enabled: !_saving && _canAdd,
                          style: TextStyle(
                            fontWeight: _phoneCtrl.text.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: _canAdd
                                ? "Ex: +22670123456"
                                : "Ajout réservé aux abonnés Ultra",
                            hintStyle: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.black38,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFF1E2DFF),
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _addPhone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2DFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            "Bloquer",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _canAdd
                        ? "Tu peux ajouter, consulter et supprimer des numéros."
                        : "Les numéros déjà bloqués restent actifs. Tu peux les consulter et les supprimer, mais pas en ajouter de nouveaux.",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : blockedPhones.isEmpty
                  ? Center(
                child: Text(
                  _canAdd
                      ? "Aucun numéro bloqué pour le moment."
                      : "Aucun numéro bloqué enregistré.",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              )
                  : ListView.separated(
                itemCount: blockedPhones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final row = blockedPhones[i];
                  final id = row['id'].toString();
                  final phone =
                  (row['blocked_phone_e164'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.90),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            phone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removePhone(id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}