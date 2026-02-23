import 'package:flutter/material.dart';
import 'ui/app_logo.dart';
import 'ui/primary_button.dart';
import 'ui/app_colors.dart';
import 'ui/faso_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool hidePwd = true;

  bool get _canLogin {
    final emailOk = emailCtrl.text.contains("@");
    final pwdOk = passwordCtrl.text.length >= 6;
    return emailOk && pwdOk;
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 70),
                const AppLogo(size: 100),
                const SizedBox(height: 25),
                const Text(
                  "Connecte-toi à ton profil FasoMatch 🚀",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 35),

                // 🔵 EMAIL (placeholder léger + texte devient plus gras quand rempli)
                FasoInput(
                  controller: emailCtrl,
                  hint: "Adresse email",
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 18),

                // 🔵 MOT DE PASSE
                FasoInput(
                  controller: passwordCtrl,
                  hint: "Mot de passe",
                  obscure: hidePwd,
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePwd ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => hidePwd = !hidePwd);
                    },
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 30),

                // 🔵 BOUTON
                PrimaryButton(
                  text: "Se connecter",
                  width: 180,
                  height: 40,
                  onPressed: _canLogin
                      ? () {
                    print("Connexion...");
                  }
                      : null,
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    // TODO: aller vers inscription
                  },
                  child: const Text(
                    "Vous n'avez pas de compte ? S'inscrire",
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}