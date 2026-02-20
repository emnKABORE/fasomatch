import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'signup_draft.dart';

// (Optionnel) Si tu utilises Firebase pour créer + email verification
// import 'package:firebase_auth/firebase_auth.dart';

class SignupStep2Screen extends StatefulWidget {
  final SignupDraft draft;
  const SignupStep2Screen({super.key, required this.draft});

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final picker = ImagePicker();
  bool isLoading = false;

  Timer? _verifyTimer;
  int _verifyTicks = 0;

  late final TextEditingController _birthCtrl;
  late final TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _birthCtrl = TextEditingController(text: _formatBirthdate(widget.draft.birthdate));
    _bioCtrl = TextEditingController(text: widget.draft.bio);
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _birthCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String _formatBirthdate(DateTime? d) {
    if (d == null) return "";
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";
  }

  int _ageFrom(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    final hasHadBirthday =
        (now.month > date.month) || (now.month == date.month && now.day >= date.day);
    if (!hasHadBirthday) age--;
    return age;
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) return;

    setState(() {
      widget.draft.birthdate = picked;
      _birthCtrl.text = _formatBirthdate(picked);
    });

    final age = _ageFrom(picked);
    if (age < 18) {
      _show("⛔ Tu dois avoir 18 ans minimum.");
    }
  }

  Future<void> _pickImage(int index) async {
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    setState(() {
      if (index == 1) widget.draft.photo1Path = x.path;
      if (index == 2) widget.draft.photo2Path = x.path;
      if (index == 3) widget.draft.photo3Path = x.path;
    });
  }

  bool get _canSubmit {
    final d = widget.draft;
    final ageOk = d.birthdate != null && _ageFrom(d.birthdate!) >= 18;
    final photoOk = (d.photo1Path ?? "").isNotEmpty; // obligatoire
    final termsOk = d.acceptedTerms;
    return ageOk && photoOk && termsOk && !isLoading;
  }

  Future<void> _createAccount() async {
    final d = widget.draft;

    // ✅ Sauvegarde bio depuis le champ
    d.bio = _bioCtrl.text.trim();

    if (d.birthdate == null) {
      _show("⚠️ Renseigne ta date de naissance.");
      return;
    }

    final age = _ageFrom(d.birthdate!);
    if (age < 18) {
      _show("⛔ FasoMatch est réservé aux 18 ans et plus. Reviens quand tu seras majeur(e).");
      return;
    }

    if (!d.acceptedTerms) {
      _show("⚠️ Tu dois accepter les CGU et la Politique de confidentialité.");
      return;
    }

    if ((d.photo1Path ?? "").isEmpty) {
      _show("⚠️ La 1ère photo est obligatoire.");
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ Plan par défaut : gratuit (avec 1 retour/jour)
      d.applyPlanDefaults("gratuit");

      // -----------------------------
      // ✅ ICI : création de compte
      // -----------------------------
      // Si tu n’as pas encore Firebase/Backend : simulation
      await Future.delayed(const Duration(seconds: 1));

      // Si tu utilises FirebaseAuth, décommente ceci :
      /*
      final auth = FirebaseAuth.instance;
      final cred = await auth.createUserWithEmailAndPassword(
        email: d.email,
        password: d.password,
      );
      await cred.user?.sendEmailVerification();
      */

      _show("✅ Compte créé. Vérifie ton email pour activer ton compte.");

      // ✅ Détection automatique de confirmation email (prêt pour Firebase)
      _startAutoEmailVerificationPolling();

      // TODO plus tard :
      // Navigator.pushReplacement(... vers choix abonnement / home)

    } catch (e) {
      _show("❌ Erreur: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startAutoEmailVerificationPolling() {
    _verifyTimer?.cancel();
    _verifyTicks = 0;

    _verifyTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      _verifyTicks++;

      // ✅ Avec Firebase (à activer quand tu branches Firebase)
      /*
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final ok = refreshed?.emailVerified ?? false;

      if (ok) {
        widget.draft.emailVerified = true;
        t.cancel();
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      */

      // ✅ Sans backend : on simule juste un rappel
      if (_verifyTicks == 5 && mounted) {
        _show("ℹ️ Toujours en attente de confirmation email…");
      }

      if (_verifyTicks >= 15) {
        t.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Image.asset('assets/images/logo.png', width: 46),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date de naissance
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    controller: _birthCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: "Date de naissance",
                      filled: true,
                    ),
                    onTap: _pickBirthdate,
                  ),
                ),

                const SizedBox(height: 26),

                // Photos
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _photoBox(
                      label: "1er photo\n(obligatoire)",
                      path: d.photo1Path,
                      onTap: () => _pickImage(1),
                    ),
                    _photoBox(
                      label: "2ème photo\n(facultatif)",
                      path: d.photo2Path,
                      onTap: () => _pickImage(2),
                    ),
                    _photoBox(
                      label: "3ème photo\n(facultatif)",
                      path: d.photo3Path,
                      onTap: () => _pickImage(3),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Bio facultative
                SizedBox(
                  width: 520,
                  child: TextFormField(
                    controller: _bioCtrl,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: "Centres d’intérêts, loisirs… (facultatif)",
                      filled: true,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // CGU obligatoire
                Row(
                  children: [
                    Checkbox(
                      value: d.acceptedTerms,
                      onChanged: (v) => setState(() => d.acceptedTerms = v ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        "J'accepte les CGU et la Politique de confidentialité",
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Center(
                  child: SizedBox(
                    width: 240,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _createAccount : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFC7EA),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFBFC7EA).withOpacity(0.55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        "Créer son compte",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoBox({
    required String label,
    required String? path,
    required VoidCallback onTap,
  }) {
    final has = (path ?? "").isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54, width: 1.2),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withOpacity(0.75),
        ),
        child: Text(
          has ? "✅\nPhoto ajoutée" : label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}