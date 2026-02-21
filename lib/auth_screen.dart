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

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Remplis tous les champs.")),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Connexion réussie")),
      );

      await pushIOS(context, const BiometricOptinScreen());
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.message))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e))),
      );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // 🔥 LOGO 100x100
                Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
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

                      // EMAIL
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: "Adresse email",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Email requis";
                          }
                          if (!v.contains("@")) {
                            return "Email invalide";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // MOT DE PASSE
                      TextFormField(
                        controller: _pwdCtrl,
                        obscureText: hidePwd,
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hidePwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                hidePwd = !hidePwd;
                              });
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Mot de passe requis";
                          }
                          if (v.length < 6) {
                            return "Minimum 6 caractères";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 25),

                      // 🔴 BOUTON SE CONNECTER
                      SizedBox(
                        width: 170,
                        height: 30,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE63946),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isLoading ? null : _login,
                          child: const Text(
                            "Se connecter",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 👆 BIOMÉTRIE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          GestureDetector(
                            onTap: () async {
                              await pushIOS(
                                context,
                                const BiometricOptinScreen(),
                              );
                            },
                            child: const Icon(
                              Icons.fingerprint,
                              size: 40,
                            ),
                          ),

                          const SizedBox(width: 30),

                          GestureDetector(
                            onTap: () async {
                              await pushIOS(
                                context,
                                const BiometricOptinScreen(),
                              );
                            },
                            child: const Icon(
                              Icons.face,
                              size: 40,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        "Vous n'avez pas de compte ?",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 10),

                      // 🔵 BOUTON INSCRIPTION
                      SizedBox(
                        width: 170,
                        height: 30,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2DFF),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isLoading ? null : _goToSignup,
                          child: const Text(
                            "S'inscrire",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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