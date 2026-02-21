import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_draft.dart';
import 'ui/faso_loading_overlay.dart';

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

  Timer? _verifyTimer;
  int _verifyTicks = 0;

  late final TextEditingController _birthCtrl;
  late final TextEditingController _bioCtrl;

  XFile? _photo1;
  XFile? _photo2;
  XFile? _photo3;

  @override
  void initState() {
    super.initState();
    _birthCtrl = TextEditingController(
      text: _formatBirthdate(widget.draft.birthdate),
    );
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.75),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black54, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black54, width: 1.2),
    ),
  );

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
    if (age < 18) _show("⛔ Tu dois avoir 18 ans minimum.");
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
    final ageOk = d.birthdate != null && _ageFrom(d.birthdate!) >= 18;
    final photoOk = _photo1 != null;
    final termsOk = d.acceptedTerms;
    return ageOk && photoOk && termsOk && !isLoading;
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

    return supabase.storage.from('profile-photos').getPublicUrl(path);
  }

  Future<void> _createAccountAndProfile() async {
    final d = widget.draft;

    final receivedUserId = widget.userId;
    if (receivedUserId == null) {
      _show("Erreur utilisateur. Recommence l'inscription.");
      return;
    }

    d.bio = _bioCtrl.text.trim();

    if (d.birthdate == null) {
      _show("⚠️ Renseigne ta date de naissance.");
      return;
    }

    final age = _ageFrom(d.birthdate!);
    if (age < 18) {
      _show("⛔ FasoMatch est réservé aux 18 ans et plus.");
      return;
    }

    if (!d.acceptedTerms) {
      _show("⚠️ Tu dois accepter les CGU et la Politique de confidentialité.");
      return;
    }

    if (_photo1 == null) {
      _show("⚠️ La 1ère photo est obligatoire.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;
      if (user == null) {
        _show("⚠️ Confirme ton email puis connecte-toi pour terminer ton profil.");
        return;
      }

      final authedUserId = user.id;

      final photo1Url =
      await _uploadPhoto(userId: authedUserId, file: _photo1!, slot: "1");
      final photo2Url = (_photo2 != null)
          ? await _uploadPhoto(userId: authedUserId, file: _photo2!, slot: "2")
          : null;
      final photo3Url = (_photo3 != null)
          ? await _uploadPhoto(userId: authedUserId, file: _photo3!, slot: "3")
          : null;

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
        'bio': d.bio,
        'photo1_url': photo1Url,
        'photo2_url': photo2Url,
        'photo3_url': photo3Url,
        'plan': 'gratuit',
        'accepted_terms': d.acceptedTerms,
        'created_at': DateTime.now().toIso8601String(),
      });

      _show("✅ Profil enregistré !");
      // TODO: Navigator.pushReplacement(...)

    } on PostgrestException catch (e) {
      _show("❌ DB error: ${e.message}");
    } on StorageException catch (e) {
      _show("❌ Storage error: ${e.message}");
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

      if (_verifyTicks == 5 && mounted) {
        _show("ℹ️ Si confirmation email activée, confirme puis reconnecte-toi.");
      }

      if (_verifyTicks >= 15) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return FasoLoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F5FF),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: isLoading ? null : () => Navigator.pop(context),
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
                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: _birthCtrl,
                      readOnly: true,
                      decoration: _deco("Date de naissance"),
                      onTap: isLoading ? null : _pickBirthdate,
                    ),
                  ),
                  const SizedBox(height: 26),

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

                  const SizedBox(height: 26),

                  SizedBox(
                    width: 520,
                    child: TextFormField(
                      controller: _bioCtrl,
                      minLines: 5,
                      maxLines: 8,
                      decoration: _deco("Centres d’intérêts, loisirs… (facultatif)"),
                      enabled: !isLoading,
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 22),

                  Center(
                    child: SizedBox(
                      width: 240,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _createAccountAndProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFC7EA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          const Color(0xFFBFC7EA).withOpacity(0.55),
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