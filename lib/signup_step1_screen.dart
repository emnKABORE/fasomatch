import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'signup_draft.dart';
import 'signup_step2_screen.dart';

import 'ui/app_colors.dart';
import 'ui/app_logo.dart';
import 'ui/primary_button.dart';

class SignupStep1Screen extends StatefulWidget {
  final SignupDraft draft;

  const SignupStep1Screen({super.key, required this.draft});

  @override
  State<SignupStep1Screen> createState() => _SignupStep1ScreenState();
}

class _SignupStep1ScreenState extends State<SignupStep1Screen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController firstNameCtrl;
  late final TextEditingController lastNameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController pwdCtrl;
  late final TextEditingController pwd2Ctrl;

  // téléphone (intl_phone_field gère le dial + drapeau)
  String _phoneComplete = ""; // ex: +22670123456
  String _phoneCountryISO = "BF"; // ex: BF

  bool hidePwd = true;
  bool hidePwd2 = true;

  bool _loading = false;
  String? _errorMsg;

  final lookingForItems = const [
    "❤️ Amour",
    "🤝 Amitié",
    "❤️🤝 Les deux",
  ];

  final genders = const ["Masculin", "Feminin"];

  final citiesBF = const [
    "Arbinda",
    "Banfora",
    "Batié",
    "Bobo-Dioulasso",
    "Bogandé",
    "Boromo",
    "Dano",
    "Dédougou",
    "Diapaga",
    "Diébougou",
    "Djibo",
    "Dori",
    "Fada N'Gourma",
    "Gaoua",
    "Gorom-Gorom",
    "Gourcy",
    "Houndé",
    "Kantchari",
    "Kaya",
    "Kombissiri",
    "Kongoussi",
    "Koudougou",
    "Koupéla",
    "Léo",
    "Manga",
    "Nouna",
    "Orodara",
    "Ouagadougou",
    "Ouahigouya",
    "Pama",
    "Pô",
    "Pouytenga",
    "Réo",
    "Sapouy",
    "Sebba",
    "Solenzo",
    "Tenkodogo",
    "Tiao",
    "Titao",
    "Tougan",
    "Yako",
    "Ziniaré",
    "Zorgho",
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.draft;

    firstNameCtrl = TextEditingController(text: d.firstName);
    lastNameCtrl = TextEditingController(text: d.lastName);
    emailCtrl = TextEditingController(text: d.email);
    pwdCtrl = TextEditingController(text: d.password);
    pwd2Ctrl = TextEditingController(text: "");

    if (d.phone.isNotEmpty) _phoneComplete = d.phone;
    if (d.country.isNotEmpty) _phoneCountryISO = d.country;
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    pwdCtrl.dispose();
    pwd2Ctrl.dispose();
    super.dispose();
  }

  InputDecoration deco(String hint) => InputDecoration(
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
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
    ),
  );

  bool get _canGoNext {
    final d = widget.draft;

    final firstOk = firstNameCtrl.text.trim().isNotEmpty;
    final lastOk = lastNameCtrl.text.trim().isNotEmpty;

    final phoneOk = _phoneComplete.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;

    final email = emailCtrl.text.trim();
    final emailOk = email.isNotEmpty && email.contains("@");

    final pwd = pwdCtrl.text;
    final pwd2 = pwd2Ctrl.text;
    final pwdOk = pwd.isNotEmpty && pwd.length >= 6 && pwd2 == pwd;

    final dropDownOk =
        d.gender.isNotEmpty && d.city.isNotEmpty && d.lookingFor.isNotEmpty;

    return firstOk && lastOk && phoneOk && emailOk && pwdOk && dropDownOk && !_loading;
  }

  void _saveDraftFromControllers() {
    final d = widget.draft;
    d.firstName = firstNameCtrl.text.trim();
    d.lastName = lastNameCtrl.text.trim();

    d.phone = _phoneComplete.trim(); // + indicatif + numéro
    d.email = emailCtrl.text.trim();
    d.password = pwdCtrl.text;

    // ISO du pays lié au téléphone (BF, FR, etc.)
    d.country = _phoneCountryISO;
  }

  String _friendlyAuthError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('already registered') ||
        msg.contains('user already') ||
        (msg.contains('email') && msg.contains('already'))) {
      return "Cet email est déjà utilisé. Essaie de te connecter.";
    }
    if (msg.contains('invalid') && msg.contains('email')) return "Email invalide.";
    if (msg.contains('password') && msg.contains('short')) return "Mot de passe trop court.";
    if (msg.contains('failed to fetch') || msg.contains('network')) {
      return "Problème de connexion internet. Réessaie.";
    }
    return "Erreur: ${e.toString()}";
  }

  Future<void> _signupWithSupabase() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final email = emailCtrl.text.trim();
      final password = pwdCtrl.text;
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(email: email, password: password);
      final userId = response.user?.id;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupStep2Screen(draft: widget.draft, userId: userId),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = _friendlyAuthError(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = _friendlyAuthError(e));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _next() async {
    _saveDraftFromControllers();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_canGoNext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Remplis tous les champs obligatoires pour continuer.")),
      );
      setState(() {});
      return;
    }

    await _signupWithSupabase();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        toolbarHeight: 86,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const AppLogo(size: 100), // ✅ harmonisé
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMsg != null) ...[
                    SizedBox(
                      width: 360,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: firstNameCtrl,
                      decoration: deco("Prénom"),
                      enabled: !_loading,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Prénom obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: lastNameCtrl,
                      decoration: deco("Nom"),
                      enabled: !_loading,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Nom obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.gender.isEmpty ? null : d.gender,
                      decoration: deco("Sexe"),
                      items: genders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: _loading ? null : (v) => setState(() => d.gender = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Sexe obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.city.isEmpty ? null : d.city,
                      decoration: deco("Ville"),
                      items: citiesBF
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: _loading ? null : (v) => setState(() => d.city = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Ville obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ Téléphone drapeau + indicatif (on ne collecte PAS un pays séparé)
                  SizedBox(
                    width: 360,
                    child: IntlPhoneField(
                      enabled: !_loading,
                      initialCountryCode: _phoneCountryISO.isEmpty ? "BF" : _phoneCountryISO,
                      decoration: deco("70 12 34 56").copyWith(hintText: "70 12 34 56"),
                      onChanged: (phone) {
                        setState(() {
                          _phoneComplete = phone.completeNumber; // +22670123456
                          _phoneCountryISO = phone.countryISOCode; // BF, FR...
                        });
                      },
                      validator: (phone) {
                        final complete = phone?.completeNumber ?? _phoneComplete;
                        final digits = complete.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 8) return "Téléphone invalide";
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: emailCtrl,
                      decoration: deco("Email"),
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = (v ?? "").trim();
                        if (value.isEmpty) return "Email obligatoire";
                        if (!value.contains("@")) return "Email invalide";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: pwdCtrl,
                      obscureText: hidePwd,
                      enabled: !_loading,
                      decoration: deco("Mot de passe").copyWith(
                        suffixIcon: IconButton(
                          onPressed: _loading ? null : () => setState(() => hidePwd = !hidePwd),
                          icon: Icon(hidePwd ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        final value = (v ?? "");
                        if (value.isEmpty) return "Mot de passe obligatoire";
                        if (value.length < 6) return "Min 6 caractères";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: pwd2Ctrl,
                      obscureText: hidePwd2,
                      enabled: !_loading,
                      decoration: deco("Confirmer le mot de passe").copyWith(
                        suffixIcon: IconButton(
                          onPressed: _loading ? null : () => setState(() => hidePwd2 = !hidePwd2),
                          icon: Icon(hidePwd2 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? "").isEmpty) return "Confirmation obligatoire";
                        if (v != pwdCtrl.text) return "Les mots de passe ne correspondent pas";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.lookingFor.isEmpty ? null : d.lookingFor,
                      decoration: deco("Je recherche"),
                      items: lookingForItems
                          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                          .toList(),
                      onChanged: _loading ? null : (v) => setState(() => d.lookingFor = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Choix obligatoire" : null,
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (!_canGoNext) ...[
                    const Text(
                      "⚠️ Remplis tous les champs obligatoires pour activer “Suivant”.",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Center(
                    child: PrimaryButton(
                      text: "Suivant",
                      width: 170,
                      height: 30,
                      loading: _loading,
                      onPressed: _canGoNext ? _next : null,
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
}