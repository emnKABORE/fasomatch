import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_step1_screen.dart';
import 'signup_draft.dart';
import 'biometric_optin_screen.dart';
import 'ui/faso_loading_overlay.dart';
import 'ui/nav.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool hidePwd = true;
  bool isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  // ✅ Input ovale (capsule) comme sur ton inscription
  InputDecoration _ovalDeco({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.95),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),

      // ✅ Bordure ovale
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Colors.black54, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Colors.black54, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Color(0xFF1E2DFF), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),

      suffixIcon: suffixIcon,
    );
  }

  // ✅ Bouton arrondi moderne
  ButtonStyle _roundedButtonStyle({
    required Color bg,
    Color? disabledBg,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      disabledBackgroundColor: disabledBg ?? bg.withOpacity(0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 0,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _friendlyAuthError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid')) {
      return "Email ou mot de passe incorrect.";
    }
    if (msg.contains('network') || msg.contains('failed')) {
      return "Problème de connexion internet.";
    }
    return "Erreur: $e";
  }

  // ✅ Mot de passe oublié : envoi du lien Supabase
  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _snack("⚠️ Entre ton email, puis clique sur “Mot de passe oublié ?”.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // ✅ IMPORTANT:
      // - Sur WEB: Uri.base.origin fonctionne (ex http://localhost:5000)
      // - Sur mobile iPhone/Android: on met un deep link (plus tard)
      final redirectTo = '${Uri.base.origin}/';

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      if (!mounted) return;
      _snack("✅ Lien envoyé. Vérifie ta boîte mail (et les spams).");
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(_friendlyAuthError(e.message));
    } catch (e) {
      if (!mounted) return;
      _snack(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack("⚠️ Remplis tous les champs.");
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _pwdCtrl.text;

    setState(() => isLoading = true);

    try {
      await FasoLoadingOverlay.run(
        context,
        message: "Connexion...",
        action: () async {
          final supabase = Supabase.instance.client;
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        },
      );

      if (!mounted) return;

      _snack("✅ Connexion réussie");

      await pushIOS(context, const BiometricOptinScreen());
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(_friendlyAuthError(e.message));
    } catch (e) {
      if (!mounted) return;
      _snack(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _goToSignup() {
    final draft = SignupDraft();
    draft.applyPlanDefaults("gratuit");
    pushIOS(context, SignupStep1Screen(draft: draft));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // ✅ LOGO 100x100
                  Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Connecte-toi à ton profil FasoMatch 🚀",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ✅ EMAIL OVALE
                        SizedBox(
                          height: 62,
                          child: TextFormField(
                            controller: _emailCtrl,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _ovalDeco(label: "Adresse email"),
                            validator: (v) {
                              final value = (v ?? "").trim();
                              if (value.isEmpty) return "Email requis";
                              if (!value.contains("@")) return "Email invalide";
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ✅ MOT DE PASSE OVALE + ŒIL
                        SizedBox(
                          height: 62,
                          child: TextFormField(
                            controller: _pwdCtrl,
                            enabled: !isLoading,
                            obscureText: hidePwd,
                            decoration: _ovalDeco(
                              label: "Mot de passe",
                              suffixIcon: IconButton(
                                icon: Icon(
                                  hidePwd ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => setState(() => hidePwd = !hidePwd),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? "";
                              if (value.isEmpty) return "Mot de passe requis";
                              if (value.length < 6) return "Minimum 6 caractères";
                              return null;
                            },
                          ),
                        ),

                        // ✅ Mot de passe oublié (aligné à droite)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : _forgotPassword,
                            child: const Text(
                              "Mot de passe oublié ?",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 🔴 BOUTON SE CONNECTER (arrondi)
                        SizedBox(
                          width: 170,
                          height: 36,
                          child: ElevatedButton(
                            style: _roundedButtonStyle(bg: const Color(0xFFE63946)),
                            onPressed: isLoading ? null : _login,
                            child: const Text(
                              "Se connecter",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 👆 BIOMÉTRIE (empreinte + visage)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: isLoading
                                  ? null
                                  : () async => pushIOS(context, const BiometricOptinScreen()),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.fingerprint, size: 40),
                              ),
                            ),
                            const SizedBox(width: 18),
                            InkWell(
                              onTap: isLoading
                                  ? null
                                  : () async => pushIOS(context, const BiometricOptinScreen()),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.face, size: 40),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          "Vous n'avez pas de compte ?",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 10),

                        // 🔵 BOUTON INSCRIPTION (arrondi)
                        SizedBox(
                          width: 170,
                          height: 36,
                          child: ElevatedButton(
                            style: _roundedButtonStyle(bg: const Color(0xFF1E2DFF)),
                            onPressed: isLoading ? null : _goToSignup,
                            child: const Text(
                              "S'inscrire",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
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