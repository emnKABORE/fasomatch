import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_draft.dart';
import 'signup_step2_screen.dart';

import 'ui/app_colors.dart';
import 'ui/app_logo.dart';
import 'ui/faso_input.dart';
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
  late final TextEditingController phoneCtrl;

  String _phoneComplete = ""; // ex: +22670123456
  String _phoneCountryISO = "BF"; // ex: BF

  bool hidePwd = true;
  bool hidePwd2 = true;

  bool _loading = false;
  String? _errorMsg;

  final lookingForItems = const [
    {'value': 'amour', 'label': '❤️ Amour'},
    {'value': 'amitie', 'label': '🤝 Amitié'},
    {'value': 'les_deux', 'label': '❤️🤝 Les deux'},
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
    phoneCtrl = TextEditingController();

    if (d.phone.isNotEmpty) {
      _phoneComplete = d.phone;
    }
    if (d.country.isNotEmpty) {
      _phoneCountryISO = d.country;
    }

    phoneCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    // Compatibilité avec les anciennes valeurs style "❤️ Amour"
    d.lookingFor = _normalizeLookingForValue(d.lookingFor);
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    pwdCtrl.dispose();
    pwd2Ctrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizeLookingForValue(String raw) {
    final v = raw.trim().toLowerCase();

    if (v == 'amour' || v.contains('amour')) return 'amour';
    if (v == 'amitie' || v.contains('amitié') || v.contains('amitie')) {
      return 'amitie';
    }
    if (v == 'les_deux' || v.contains('les deux')) return 'les_deux';

    return raw;
  }

  String _emailRedirectTo() {
    if (kIsWeb) {
      return "${Uri.base.origin}/auth/callback";
    }
    return "https://fasomatch.app/auth/callback";
  }

  InputDecoration deco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.75),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      borderSide:
      const BorderSide(color: AppColors.primaryBlue, width: 1.4),
    ),
  );

  bool get _canGoNext {
    final d = widget.draft;

    final firstOk = firstNameCtrl.text.trim().isNotEmpty;
    final lastOk = lastNameCtrl.text.trim().isNotEmpty;

    final phoneOk =
        _phoneComplete.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;

    final email = emailCtrl.text.trim();
    final emailOk = email.isNotEmpty && email.contains("@");

    final pwd = pwdCtrl.text;
    final pwd2 = pwd2Ctrl.text;
    final pwdOk = pwd.isNotEmpty && pwd.length >= 6 && pwd2 == pwd;

    final dropDownOk =
        d.gender.isNotEmpty && d.city.isNotEmpty && d.lookingFor.isNotEmpty;

    return firstOk &&
        lastOk &&
        phoneOk &&
        emailOk &&
        pwdOk &&
        dropDownOk &&
        !_loading;
  }

  void _saveDraftFromControllers() {
    final d = widget.draft;
    d.firstName = firstNameCtrl.text.trim();
    d.lastName = lastNameCtrl.text.trim();
    d.phone = _phoneComplete.trim();
    d.email = emailCtrl.text.trim();
    d.password = pwdCtrl.text;
    d.country = _phoneCountryISO;
    d.lookingFor = _normalizeLookingForValue(d.lookingFor);
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();

    if (msg.contains('already registered') ||
        msg.contains('user already') ||
        (msg.contains('email') && msg.contains('already'))) {
      return "Cet email est déjà utilisé. Essaie de te connecter.";
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return "Email invalide.";
    }
    if (msg.contains('password') &&
        (msg.contains('short') || msg.contains('6'))) {
      return "Mot de passe trop court (min 6 caractères).";
    }
    if (msg.contains('failed to fetch') ||
        msg.contains('network') ||
        msg.contains('socket')) {
      return "Problème de connexion internet. Réessaie.";
    }
    if (msg.contains('redirect') || msg.contains('url')) {
      return "Erreur de redirection email. Vérifie les Redirect URLs dans Supabase Auth.";
    }

    return "Erreur: $raw";
  }

  Future<void> _signupWithSupabase() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      _saveDraftFromControllers();
      final d = widget.draft;

      final email = emailCtrl.text.trim();
      final password = pwdCtrl.text;
      final supabase = Supabase.instance.client;

      final redirectTo = _emailRedirectTo();
      debugPrint("SIGNUP redirectTo=$redirectTo email=$email");

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectTo,
        data: {
          "first_name": d.firstName,
          "last_name": d.lastName,
          "phone": d.phone,
          "country_iso": d.country,
          "gender": d.gender,
          "city": d.city,
          "looking_for": d.lookingFor, // amour / amitie / les_deux
        },
      );

      debugPrint(
        "SIGNUP OK user=${response.user?.id} session=${response.session != null} confirmedAt=${response.user?.emailConfirmedAt}",
      );

      final userId = response.user?.id;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SignupStep2Screen(draft: widget.draft, userId: userId),
        ),
      );
    } on AuthException catch (e) {
      debugPrint("AUTH ERROR: status=${e.statusCode} message=${e.message}");

      if (!mounted) return;
      setState(() => _errorMsg = _friendlyAuthError(e.message));
    } catch (e) {
      debugPrint("UNKNOWN ERROR: $e");
      if (!mounted) return;
      setState(() => _errorMsg = _friendlyAuthError(e.toString()));
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
        const SnackBar(
          content: Text(
            "⚠️ Remplis tous les champs obligatoires pour continuer.",
          ),
        ),
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
        title: const AppLogo(size: 100),
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
                          border:
                          Border.all(color: Colors.red.withOpacity(0.3)),
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
                    child: FasoInput(
                      controller: firstNameCtrl,
                      hint: "Prénom",
                      enabled: !_loading,
                      borderRadius: 10,
                      fillOpacity: 0.75,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Prénom obligatoire"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: FasoInput(
                      controller: lastNameCtrl,
                      hint: "Nom",
                      enabled: !_loading,
                      borderRadius: 10,
                      fillOpacity: 0.75,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Nom obligatoire"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.gender.isEmpty ? null : d.gender,
                      decoration: deco("Sexe"),
                      items: genders
                          .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g),
                      ))
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => d.gender = v ?? ""),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? "Sexe obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.city.isEmpty ? null : d.city,
                      decoration: deco("Ville"),
                      items: citiesBF
                          .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => d.city = v ?? ""),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? "Ville obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: IntlPhoneField(
                      controller: phoneCtrl,
                      enabled: !_loading,
                      initialCountryCode:
                      _phoneCountryISO.isEmpty ? "BF" : _phoneCountryISO,
                      disableLengthCheck: true,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: phoneCtrl.text.trim().isEmpty
                            ? FontWeight.normal
                            : FontWeight.w700,
                      ),
                      dropdownTextStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                      ),
                      decoration: deco("70 12 34 56").copyWith(
                        hintText: "70 12 34 56",
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontWeight: FontWeight.normal,
                        ),
                        counterText: "",
                      ),
                      onChanged: (phone) {
                        setState(() {
                          _phoneComplete = phone.completeNumber;
                          _phoneCountryISO = phone.countryISOCode;
                        });
                      },
                      validator: (phone) {
                        final complete = phone?.completeNumber ?? _phoneComplete;
                        final digits =
                        complete.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 8) return "Téléphone invalide";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: FasoInput(
                      controller: emailCtrl,
                      hint: "Email",
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      borderRadius: 10,
                      fillOpacity: 0.75,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      onChanged: (_) => setState(() {}),
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
                    child: FasoInput(
                      controller: pwdCtrl,
                      hint: "Mot de passe",
                      enabled: !_loading,
                      obscure: hidePwd,
                      borderRadius: 10,
                      fillOpacity: 0.75,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => hidePwd = !hidePwd),
                        icon: Icon(
                          hidePwd ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
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
                    child: FasoInput(
                      controller: pwd2Ctrl,
                      hint: "Confirmer le mot de passe",
                      enabled: !_loading,
                      obscure: hidePwd2,
                      borderRadius: 10,
                      fillOpacity: 0.75,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => hidePwd2 = !hidePwd2),
                        icon: Icon(
                          hidePwd2 ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if ((v ?? "").isEmpty) {
                          return "Confirmation obligatoire";
                        }
                        if (v != pwdCtrl.text) {
                          return "Les mots de passe ne correspondent pas";
                        }
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
                          .map(
                            (item) => DropdownMenuItem<String>(
                          value: item['value']!,
                          child: Text(item['label']!),
                        ),
                      )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => d.lookingFor = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Choix obligatoire"
                          : null,
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