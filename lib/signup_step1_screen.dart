import 'package:flutter/material.dart';
import 'signup_draft.dart';
import 'signup_step2_screen.dart';

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
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController pwdCtrl;
  late final TextEditingController pwd2Ctrl;

  bool hidePwd = true;
  bool hidePwd2 = true;

  final countries = const [
    "Burkina",
    "Mali",
    "Niger",
    "Cote d'ivoire",
    "Senegal",
    "France",
    "USA",
    "Canada"
  ];

  final lookingForItems = const [
    "❤️ Amour",
    "🤝🏿 Amitié",
    "❤️🤝🏿 Les deux",
  ];

  final genders = const ["Masculin", "Feminin"];

  // ✅ Villes BF (triées A→Z, doublons supprimés)
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
    "Tiao", // si tu ne veux pas cette ville, supprime-la
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
    phoneCtrl = TextEditingController(text: d.phone);
    emailCtrl = TextEditingController(text: d.email);
    pwdCtrl = TextEditingController(text: d.password);
    pwd2Ctrl = TextEditingController(text: "");
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
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
  );

  /// ✅ Active/désactive le bouton SANS appeler validate() en boucle
  bool get _canGoNext {
    final d = widget.draft;

    final firstOk = firstNameCtrl.text.trim().isNotEmpty;
    final lastOk = lastNameCtrl.text.trim().isNotEmpty;

    final phone = phoneCtrl.text.trim();
    final phoneOk = phone.isNotEmpty && phone.length >= 8;

    final email = emailCtrl.text.trim();
    final emailOk = email.isNotEmpty && email.contains("@");

    final pwd = pwdCtrl.text;
    final pwd2 = pwd2Ctrl.text;
    final pwdOk = pwd.isNotEmpty && pwd.length >= 6 && pwd2 == pwd;

    final dropDownOk = d.gender.isNotEmpty &&
        d.city.isNotEmpty &&
        d.country.isNotEmpty &&
        d.lookingFor.isNotEmpty;

    return firstOk && lastOk && phoneOk && emailOk && pwdOk && dropDownOk;
  }

  void _saveDraftFromControllers() {
    final d = widget.draft;
    d.firstName = firstNameCtrl.text.trim();
    d.lastName = lastNameCtrl.text.trim();
    d.phone = phoneCtrl.text.trim();
    d.email = emailCtrl.text.trim();
    d.password = pwdCtrl.text;
  }

  void _next() {
    _saveDraftFromControllers();

    // ✅ Ici on valide vraiment le formulaire
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_canGoNext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Remplis tous les champs obligatoires.")),
      );
      setState(() {});
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupStep2Screen(draft: widget.draft),
      ),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: firstNameCtrl,
                      decoration: deco("Prénom"),
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
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Nom obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sexe
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.gender.isEmpty ? null : d.gender,
                      decoration: deco("Sexe"),
                      items: genders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => d.gender = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Sexe obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ville
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.city.isEmpty ? null : d.city,
                      decoration: deco("Ville"),
                      items: citiesBF
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => d.city = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Ville obligatoire" : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pays + Téléphone
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: d.country.isEmpty ? null : d.country,
                          decoration: deco("Pays"),
                          items: countries
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => d.country = v ?? ""),
                          validator: (v) =>
                          (v == null || v.isEmpty) ? "Pays obligatoire" : null,
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: TextFormField(
                          controller: phoneCtrl,
                          decoration: deco("70 12 34 56"),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final value = (v ?? "").trim();
                            if (value.isEmpty) return "Téléphone obligatoire";
                            if (value.length < 8) return "Téléphone invalide";
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: emailCtrl,
                      decoration: deco("Email"),
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

                  // Mot de passe + bouton Afficher
                  Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextFormField(
                          controller: pwdCtrl,
                          obscureText: hidePwd,
                          decoration: deco("Mot de passe").copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => hidePwd = !hidePwd),
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
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => setState(() {
                            hidePwd = !hidePwd;
                            hidePwd2 = !hidePwd2;
                          }),
                          child: const Text(
                            "Afficher",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: 360,
                    child: TextFormField(
                      controller: pwd2Ctrl,
                      obscureText: hidePwd2,
                      decoration: deco("Confirmer le mot de passe"),
                      validator: (v) {
                        if ((v ?? "").isEmpty) return "Confirmation obligatoire";
                        if (v != pwdCtrl.text) return "Les mots de passe ne correspondent pas";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Je recherche
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      value: d.lookingFor.isEmpty ? null : d.lookingFor,
                      decoration: deco("Je recherche"),
                      items: lookingForItems
                          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                          .toList(),
                      onChanged: (v) => setState(() => d.lookingFor = v ?? ""),
                      validator: (v) => (v == null || v.isEmpty) ? "Choix obligatoire" : null,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _canGoNext ? _next : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFC7EA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          const Color(0xFFBFC7EA).withOpacity(0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Suivant",
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
}
