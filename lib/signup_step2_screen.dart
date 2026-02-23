import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_draft.dart';
import 'ui/app_colors.dart';
import 'ui/app_logo.dart';
import 'ui/primary_button.dart';
import 'ui/birthdate_picker_field.dart';
import 'ui/faso_loading_overlay.dart';

import 'biometric_optin_screen.dart'; // ✅ tu l’as déjà

class SignupStep2Screen extends StatefulWidget {
  final SignupDraft draft;
  final String? userId;

  const SignupStep2Screen({
    super.key,
    required this.draft,
    required this.userId,
  });

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final picker = ImagePicker();
  bool isLoading = false;

  late final TextEditingController _bioCtrl;

  XFile? _photo1;
  XFile? _photo2;
  XFile? _photo3;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.draft.bio);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  int _ageFrom(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    final hasHadBirthday =
        (now.month > date.month) || (now.month == date.month && now.day >= date.day);
    if (!hasHadBirthday) age--;
    return age;
  }

  Future<void> _showDialog({
    required String title,
    required String message,
    String okText = "OK",
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage(int index) async {
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    setState(() {
      if (index == 1) _photo1 = x;
      if (index == 2) _photo2 = x;
      if (index == 3) _photo3 = x;

      if (index == 1) widget.draft.photo1Path = x.name;
      if (index == 2) widget.draft.photo2Path = x.name;
      if (index == 3) widget.draft.photo3Path = x.name;
    });
  }

  bool get _canSubmit {
    final d = widget.draft;
    final birthOk = d.birthdate != null;
    final ageOk = d.birthdate != null && _ageFrom(d.birthdate!) >= 18;
    final photoOk = _photo1 != null; // ✅ photo 1 obligatoire
    final termsOk = d.acceptedTerms;

    return birthOk && ageOk && photoOk && termsOk && !isLoading;
  }

  Future<String> _uploadPhoto({
    required String userId,
    required XFile file,
    required String slot,
  }) async {
    final supabase = Supabase.instance.client;

    final Uint8List bytes = await file.readAsBytes();
    final ext = (file.name.contains('.')) ? file.name.split('.').last : 'jpg';
    final path = "$userId/photo_$slot.$ext";

    await supabase.storage.from('profile-photos').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = supabase.storage.from('profile-photos').getPublicUrl(path);
    return publicUrl;
  }

  Future<void> _finalizeProfileAfterLogin(String authedUserId) async {
    final d = widget.draft;
    final supabase = Supabase.instance.client;

    // Bio facultative ✅
    d.bio = _bioCtrl.text.trim();

    // Upload photo1 obligatoire ✅
    final photo1Url = await _uploadPhoto(userId: authedUserId, file: _photo1!, slot: "1");

    // Upload optionnels ✅
    final photo2Url =
    (_photo2 != null) ? await _uploadPhoto(userId: authedUserId, file: _photo2!, slot: "2") : null;
    final photo3Url =
    (_photo3 != null) ? await _uploadPhoto(userId: authedUserId, file: _photo3!, slot: "3") : null;

    d.applyPlanDefaults("gratuit");

    await supabase.from('profiles').upsert({
      'id': authedUserId,
      'first_name': d.firstName,
      'last_name': d.lastName,
      'phone': d.phone,
      'email': d.email,
      'gender': d.gender,
      'city': d.city,
      'country': d.country,
      'looking_for': d.lookingFor,
      'birthdate': d.birthdate!.toIso8601String().substring(0, 10),
      'bio': d.bio.isEmpty ? null : d.bio,
      'photo1_url': photo1Url,
      'photo2_url': photo2Url,
      'photo3_url': photo3Url,
      'plan': 'gratuit',
      'accepted_terms': d.acceptedTerms,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onCreatePressed() async {
    final d = widget.draft;

    // Validations + alert 18+ ✅
    if (d.birthdate == null) {
      await _showDialog(
        title: "Date de naissance",
        message: "⚠️ Renseigne ta date de naissance pour continuer.",
      );
      return;
    }

    final age = _ageFrom(d.birthdate!);
    if (age < 18) {
      await _showDialog(
        title: "Accès interdit",
        message: "⛔ FasoMatch est réservé aux personnes de 18 ans et plus.",
      );
      return;
    }

    if (_photo1 == null) {
      await _showDialog(
        title: "Photo obligatoire",
        message: "⚠️ La 1ère photo est obligatoire.",
      );
      return;
    }

    if (!d.acceptedTerms) {
      await _showDialog(
        title: "Conditions",
        message: "⚠️ Tu dois accepter les CGU et la Politique de confidentialité.",
      );
      return;
    }

    // Message “confirme ton mail” ✅
    await _showDialog(
      title: "Dernière étape",
      message:
      "✅ Compte créé.\n\n📩 Va confirmer ton email (regarde aussi tes spams).\n\nDès que c’est confirmé, FasoMatch continue automatiquement ici.",
      okText: "J’ai compris",
    );

    // 👉 on passe à l’écran d’attente qui détecte la confirmation automatiquement
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmailConfirmWaitScreen(
          draft: widget.draft,
          bioText: _bioCtrl.text,
          photo1: _photo1!,
          photo2: _photo2,
          photo3: _photo3,
          finalizeProfile: _finalizeProfileAfterLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return FasoLoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: true,

          // ✅ Fix logo visible (plus d’écrasement)
          toolbarHeight: 120,
          title: const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 10),
            child: AppLogo(size: 80),
          ),

          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: isLoading ? null : () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Date
                  SizedBox(
                    width: 360,
                    child: BirthdatePickerField(
                      value: d.birthdate,
                      enabled: !isLoading,
                      onChanged: (picked) async {
                        setState(() => d.birthdate = picked);

                        if (picked != null && _ageFrom(picked) < 18) {
                          await _showDialog(
                            title: "Accès interdit",
                            message: "⛔ Tu dois avoir 18 ans minimum pour utiliser FasoMatch.",
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _photoBox(
                        label: "1er photo\n(obligatoire)",
                        has: _photo1 != null,
                        onTap: isLoading ? null : () => _pickImage(1),
                      ),
                      _photoBox(
                        label: "2ème photo\n(facultatif)",
                        has: _photo2 != null,
                        onTap: isLoading ? null : () => _pickImage(2),
                      ),
                      _photoBox(
                        label: "3ème photo\n(facultatif)",
                        has: _photo3 != null,
                        onTap: isLoading ? null : () => _pickImage(3),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ✅ Bio facultative
                  SizedBox(
                    width: 520,
                    child: TextFormField(
                      controller: _bioCtrl,
                      minLines: 5,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: "Centres d’intérêts, loisirs… (facultatif)",
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.75),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black54, width: 1.2),
                        ),
                      ),
                      enabled: !isLoading,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: d.acceptedTerms,
                        onChanged: isLoading
                            ? null
                            : (v) => setState(() => d.acceptedTerms = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          "J'accepte les CGU et la Politique de confidentialité",
                          style: TextStyle(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: PrimaryButton(
                      text: "Créer son compte",
                      width: 220,
                      height: 44,
                      loading: isLoading,
                      onPressed: _canSubmit ? _onCreatePressed : null,
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

  Widget _photoBox({
    required String label,
    required bool has,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54, width: 1.2),
          borderRadius: BorderRadius.circular(12),
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

/// ---------------------------------------------------------------------------
/// Écran d’attente : détecte la confirmation automatiquement
/// ---------------------------------------------------------------------------
class EmailConfirmWaitScreen extends StatefulWidget {
  final SignupDraft draft;
  final String bioText;
  final XFile photo1;
  final XFile? photo2;
  final XFile? photo3;

  final Future<void> Function(String authedUserId) finalizeProfile;

  const EmailConfirmWaitScreen({
    super.key,
    required this.draft,
    required this.bioText,
    required this.photo1,
    required this.photo2,
    required this.photo3,
    required this.finalizeProfile,
  });

  @override
  State<EmailConfirmWaitScreen> createState() => _EmailConfirmWaitScreenState();
}

class _EmailConfirmWaitScreenState extends State<EmailConfirmWaitScreen> {
  Timer? _timer;
  bool _busy = false;
  int _ticks = 0;
  String _status = "En attente de confirmation email…";

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tryAutoLogin());
  }

  Future<void> _tryAutoLogin() async {
    if (_busy) return;
    _busy = true;

    try {
      _ticks++;

      // ⛔ limite de temps (ex: 4 minutes)
      if (_ticks > 80) {
        setState(() => _status = "Toujours pas confirmé. Vérifie tes spams ou renvoie le mail.");
        _busy = false;
        return;
      }

      setState(() => _status = "Vérification…");

      final supabase = Supabase.instance.client;

      // ✅ Dès que l’email est confirmé, ce login réussit (même si confirmé sur autre appareil)
      final res = await supabase.auth.signInWithPassword(
        email: widget.draft.email.trim(),
        password: widget.draft.password,
      );

      final user = res.user;
      if (user == null) {
        setState(() => _status = "En attente de confirmation email…");
        _busy = false;
        return;
      }

      // Vérif email confirmé
      final confirmed = user.emailConfirmedAt != null;
      if (!confirmed) {
        setState(() => _status = "Email pas encore confirmé…");
        _busy = false;
        return;
      }

      // ✅ confirm détectée → on finalize profil
      _timer?.cancel();
      setState(() => _status = "Confirmation détectée ✅ Finalisation du profil…");

      await widget.finalizeProfile(user.id);

      if (!mounted) return;

      // ✅ Welcome
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Bienvenue sur FasoMatch 🎉"),
          content: const Text(
            "Ton email est confirmé ✅\n\nOn va te proposer l’empreinte / FaceID pour te connecter plus vite la prochaine fois.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Continuer"),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // ✅ biométrie
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BiometricOptinScreen()),
      );
    } catch (e) {
      // le plus fréquent ici : email pas confirmé → Supabase renvoie une erreur
      setState(() => _status = "En attente de confirmation email…");
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 110,
        title: const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 10),
          child: AppLogo(size: 70),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 54),
                const SizedBox(height: 14),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  "📩 Confirme ton email puis reviens ici.\nDès que c’est confirmé, FasoMatch continue tout seul.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black.withOpacity(0.65)),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  text: "Aller au Swipe",
                  width: 200,
                  height: 42,
                  onPressed: () {
                    // ✅ si tu veux permettre d'aller au swipe après biométrie
                    Navigator.pushReplacementNamed(context, '/swipe');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}