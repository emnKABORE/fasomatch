import 'package:flutter/material.dart';

class DiscreetModeScreen extends StatefulWidget {
  final String currentPlan; // gratuit / premium / ultra
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
  final List<String> blockedPhones = [];

  bool get _canAccess => widget.currentPlan == "ultra";

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _askUpgrade() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🔒 Mode discret = Ultra"),
        content: const Text(
            "Bloquer des profils par numéro est réservé aux Ultra."),
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

  void _addPhone() {
    if (!_canAccess) return _askUpgrade();
    final t = _phoneCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      blockedPhones.add(t);
      _phoneCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        title: const Text("Mode discret",
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Bloquer par numéro",
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: "Ex: +22670123456",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _addPhone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text("Bloquer",
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      )
                    ],
                  ),
                  if (!_canAccess) ...[
                    const SizedBox(height: 10),
                    const Text(
                      "🔒 Réservé Ultra",
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w700),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: blockedPhones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = blockedPhones[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () {
                            if (!_canAccess) return _askUpgrade();
                            setState(() => blockedPhones.removeAt(i));
                          },
                          icon: const Icon(Icons.delete_outline),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}