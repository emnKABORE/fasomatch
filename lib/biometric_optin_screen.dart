import 'package:flutter/material.dart';
import 'ui/app_colors.dart';
import 'ui/primary_button.dart';
import 'ui/app_logo.dart';

class BiometricOptinScreen extends StatelessWidget {
  const BiometricOptinScreen({super.key});

  void _goSwipe(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/swipe');
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
        automaticallyImplyLeading: false, // ✅ pas de retour (flow onboarding)
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 60),
                const SizedBox(height: 14),
                const Text(
                  "Connexion rapide",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  "Souhaites-tu te connecter plus vite la prochaine fois avec ton empreinte ou FaceID ?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 22),

                // ✅ OUI
                PrimaryButton(
                  text: "Oui, activer",
                  width: 220,
                  height: 44,
                  onPressed: () async {
                    // TODO plus tard:
                    // - local_auth (TouchID/FaceID)
                    // - sauvegarde (SecureStorage)
                    _goSwipe(context);
                  },
                ),

                const SizedBox(height: 12),

                // ✅ NON
                TextButton(
                  onPressed: () {
                    _goSwipe(context);
                  },
                  child: const Text(
                    "Non, plus tard",
                    style: TextStyle(fontWeight: FontWeight.w800),
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