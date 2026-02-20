import 'package:flutter/material.dart';
import 'signup_step1_screen.dart';
import 'signup_draft.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool rememberMe = false;
  bool hidePwd = true;
  bool isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE63946), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  void _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    // ✅ SIMULATION (plus tard on branche Firebase/Backend)
    await Future.delayed(const Duration(seconds: 1));

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Connexion OK (à brancher)")),
    );
  }

  void _goToSignup() {
    final draft = SignupDraft();

    // ✅ Plan gratuit par défaut (si ta classe le supporte)
    // (si tu n'as pas encore cette méthode, supprime ces 2 lignes)
    try {
      draft.applyPlanDefaults("gratuit");
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupStep1Screen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo + titre
                  Image.asset('assets/images/logo.png', width: 90),
                  const SizedBox(height: 10),
                  const Text(
                    "Connecte-toi à ton profil FasoMatch 🚀",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Adresse email",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.85),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              hint: "Tapez votre adresse email",
                            ),
                            validator: (v) {
                              final value = (v ?? "").trim();
                              if (value.isEmpty) return "Veuillez renseigner l’email";
                              if (!value.contains("@")) return "Email invalide";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Mot de passe",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.85),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pwdCtrl,
                            obscureText: hidePwd,
                            decoration: _inputDecoration(
                              hint: "Tapez votre mot de passe",
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => hidePwd = !hidePwd),
                                icon: Icon(
                                  hidePwd ? Icons.visibility_off : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (v) {
                              final value = (v ?? "");
                              if (value.isEmpty) return "Veuillez renseigner le mot de passe";
                              if (value.length < 6) return "Minimum 6 caractères";
                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          // Remember me
                          Row(
                            children: [
                              Checkbox(
                                value: rememberMe,
                                onChanged: (v) => setState(() => rememberMe = v ?? false),
                              ),
                              const Text("Se souvenir de moi"),
                            ],
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Mot de passe oublié (écran à faire)"),
                                  ),
                                );
                              },
                              child: const Text(
                                "Mot de passe oublié ?",
                                style: TextStyle(
                                  color: Colors.red,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Login button
                          SizedBox(
                            width: 230,
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE63946),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text(
                                "Se connecter",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    "Vous n'avez pas de compte ?",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Signup CTA → Step 1 (infos personnelles)
                  SizedBox(
                    width: 180,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2DFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _goToSignup,
                      child: const Text(
                        "S'inscrire",
                        style: TextStyle(fontWeight: FontWeight.w900),
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
