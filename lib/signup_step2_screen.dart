import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'signup_draft.dart';
import 'ui/app_colors.dart';
import 'ui/app_logo.dart';
import 'ui/birthdate_picker_field.dart';
import 'ui/faso_loading_overlay.dart';
import 'ui/primary_button.dart';

class LegalLinks {
  static const privacy =
      "https://walnut-damselfly-2b4.notion.site/Politique-de-confidentialit-314de39099da801f953ed31f7bb02b77?source=copy_link";

  static const legal =
      "https://walnut-damselfly-2b4.notion.site/MENTIONS-L-GALES-Version-conforme-Burkina-314de39099da8048840feffd0a69cc00?pvs=73";

  static const cgu =
      "https://walnut-damselfly-2b4.notion.site/CGU-Version-soci-t-314de39099da80ed9b14d739cf80a751?source=copy_link";

  static const supportEmail = "support@fasomatch.app";
}

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class SignupStep2Screen extends StatefulWidget {
  final SignupDraft draft;
  final String userId;

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

    if (widget.draft.photo1Path != null && widget.draft.photo1Path!.isNotEmpty) {
      _photo1 = XFile(widget.draft.photo1Path!);
    }
    if (widget.draft.photo2Path != null && widget.draft.photo2Path!.isNotEmpty) {
      _photo2 = XFile(widget.draft.photo2Path!);
    }
    if (widget.draft.photo3Path != null && widget.draft.photo3Path!.isNotEmpty) {
      _photo3 = XFile(widget.draft.photo3Path!);
    }
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

  Future<void> _pickImage(int index) async {
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      if (index == 1) _photo1 = x;
      if (index == 2) _photo2 = x;
      if (index == 3) _photo3 = x;

      if (index == 1) widget.draft.photo1Path = x.path;
      if (index == 2) widget.draft.photo2Path = x.path;
      if (index == 3) widget.draft.photo3Path = x.path;
    });
  }

  bool get _canSubmit {
    final d = widget.draft;
    final birthOk = d.birthdate != null;
    final ageOk = d.birthdate != null && _ageFrom(d.birthdate!) >= 18;
    final photoOk = _photo1 != null;
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

    return supabase.storage.from('profile-photos').getPublicUrl(path);
  }

  Future<void> _finalizeProfileAfterLogin(String authedUserId) async {
    final d = widget.draft;
    final supabase = Supabase.instance.client;

    d.bio = _bioCtrl.text.trim();

    final photo1Url = await _uploadPhoto(
      userId: authedUserId,
      file: _photo1!,
      slot: "1",
    );

    final photo2Url = (_photo2 != null)
        ? await _uploadPhoto(userId: authedUserId, file: _photo2!, slot: "2")
        : null;

    final photo3Url = (_photo3 != null)
        ? await _uploadPhoto(userId: authedUserId, file: _photo3!, slot: "3")
        : null;

    final List<String> photoUrls = [
      photo1Url,
      if (photo2Url != null) photo2Url,
      if (photo3Url != null) photo3Url,
    ];

    await supabase.from('profiles').upsert({
      'id': authedUserId,
      'first_name': d.firstName,
      'last_name': d.lastName,
      'birth_year': d.birthdate!.year,
      'gender': d.gender,
      'looking_for': d.lookingFor,
      'bio': d.bio.isEmpty ? null : d.bio,
      'city': d.city,
      'interests': <String>[],
      'avatar_url': photo1Url,
      'photos': photoUrls,
      'is_verified': false,
      'plan': 'gratuit',
      'phone': d.phone,
      'is_active': true,
      'account_status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onCreatePressed() async {
    final d = widget.draft;

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
        message:
        "⚠️ Tu dois accepter les CGU, la Politique de confidentialité et les Mentions légales.",
      );
      return;
    }

    d.bio = _bioCtrl.text.trim();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmailConfirmWaitScreen(
          draft: widget.draft,
          userId: widget.userId,
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
          toolbarHeight: 100,
          title: const AppLogo(size: 80),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 28),
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
                            message:
                            "⛔ Tu dois avoir 18 ans minimum pour utiliser FasoMatch.",
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
                        label: "Photo 1\n(obligatoire)",
                        file: _photo1,
                        onTap: isLoading ? null : () => _pickImage(1),
                      ),
                      _photoBox(
                        label: "Photo 2",
                        file: _photo2,
                        onTap: isLoading ? null : () => _pickImage(2),
                      ),
                      _photoBox(
                        label: "Photo 3",
                        file: _photo3,
                        onTap: isLoading ? null : () => _pickImage(3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 520,
                    child: TextFormField(
                      controller: _bioCtrl,
                      minLines: 5,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: "Bio (facultatif)",
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.75),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          const BorderSide(color: Colors.black54, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryBlue,
                            width: 1.4,
                          ),
                        ),
                      ),
                      enabled: !isLoading,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: d.acceptedTerms,
                        onChanged: isLoading
                            ? null
                            : (v) => setState(() => d.acceptedTerms = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _LegalConsentText(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: PrimaryButton(
                      text: "Créer mon compte",
                      width: 220,
                      height: 44,
                      loading: isLoading,
                      onPressed: _canSubmit ? _onCreatePressed : null,
                    ),
                  ),
                  const SizedBox(height: 16),
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
    required XFile? file,
    required VoidCallback? onTap,
  }) {
    Widget preview;

    if (file == null) {
      preview = Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (kIsWeb) {
      preview = FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (!snapshot.hasData) {
            return const Center(child: Icon(Icons.broken_image_outlined));
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      preview = Image.file(
        File(file.path),
        fit: BoxFit.cover,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54, width: 1.2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.75),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            if (file != null)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalConsentText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: Colors.black.withOpacity(0.8));
    final link = const TextStyle(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w700,
    );

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: "J’accepte les "),
          TextSpan(
            text: "CGU",
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl(LegalLinks.cgu),
          ),
          const TextSpan(text: ", la "),
          TextSpan(
            text: "Politique de confidentialité",
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl(LegalLinks.privacy),
          ),
          const TextSpan(text: " et les "),
          TextSpan(
            text: "Mentions légales",
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl(LegalLinks.legal),
          ),
          const TextSpan(text: "."),
          const TextSpan(text: "\n\nSupport : "),
          TextSpan(
            text: LegalLinks.supportEmail,
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl("mailto:${LegalLinks.supportEmail}"),
          ),
        ],
      ),
    );
  }
}

class EmailConfirmWaitScreen extends StatefulWidget {
  final SignupDraft draft;
  final String userId;
  final Future<void> Function(String authedUserId) finalizeProfile;

  const EmailConfirmWaitScreen({
    super.key,
    required this.draft,
    required this.userId,
    required this.finalizeProfile,
  });

  @override
  State<EmailConfirmWaitScreen> createState() => _EmailConfirmWaitScreenState();
}

class _EmailConfirmWaitScreenState extends State<EmailConfirmWaitScreen> {
  Timer? _timer;
  bool _busy = false;
  bool _resendBusy = false;
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
    _timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _tryAutoLogin(),
    );
  }

  Future<void> _tryAutoLogin() async {
    if (_busy) return;
    _busy = true;

    try {
      _ticks++;

      if (_ticks > 120) {
        if (mounted) {
          setState(() {
            _status =
            "Toujours pas confirmé. Vérifie tes spams ou renvoie le mail.";
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _status = "Vérification de la confirmation…");
      }

      final supabase = Supabase.instance.client;

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null && currentUser.emailConfirmedAt != null) {
        _timer?.cancel();

        if (mounted) {
          setState(() => _status = "Confirmation détectée ✅ Finalisation du profil…");
        }

        await widget.finalizeProfile(currentUser.id);

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(context, '/swipe', (_) => false);
        return;
      }

      final res = await supabase.auth.signInWithPassword(
        email: widget.draft.email.trim(),
        password: widget.draft.password,
      );

      final user = res.user;
      if (user == null) {
        if (mounted) {
          setState(() => _status = "En attente de confirmation email…");
        }
        return;
      }

      final confirmed = user.emailConfirmedAt != null;
      if (!confirmed) {
        if (mounted) {
          setState(() => _status = "Email pas encore confirmé…");
        }
        await supabase.auth.signOut();
        return;
      }

      _timer?.cancel();

      if (mounted) {
        setState(() => _status = "Confirmation détectée ✅ Finalisation du profil…");
      }

      await widget.finalizeProfile(user.id);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/swipe', (_) => false);
    } catch (e) {
      debugPrint('Auto login confirm error: $e');
      if (mounted) {
        setState(() => _status = "En attente de confirmation email…");
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _resendEmail() async {
    if (_resendBusy) return;

    setState(() => _resendBusy = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.draft.email.trim(),
        emailRedirectTo: kIsWeb
            ? "${Uri.base.origin}/auth/callback"
            : "fasomatch://auth/callback",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email renvoyé. Vérifie ta boîte mail."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible de renvoyer l’email : $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  Future<void> _manualCheck() async {
    await _tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 100,
        leading: const SizedBox.shrink(),
        title: const AppLogo(size: 80),
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
                const Text(
                  "Confirme ton email",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.draft.email.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  "📩 Va confirmer ton email dans ta boîte de réception.\n\nSi tu confirmes depuis ce téléphone, FasoMatch pourra s’ouvrir automatiquement.\nSinon, reviens ici : la validation sera détectée automatiquement.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black.withOpacity(0.65)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 260,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _resendBusy ? null : _resendEmail,
                    child: Text(
                      _resendBusy
                          ? "Envoi..."
                          : "Email non reçu ? Renvoyer",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _manualCheck,
                    child: const Text(
                      "J’ai déjà confirmé",
                      style: TextStyle(fontWeight: FontWeight.w800),
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
}