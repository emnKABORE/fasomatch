import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reset_password_screen.dart';
import 'swipe/swipe_screen.dart';
import 'welcome_screen.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _message = "Validation en cours...";

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final uri = Uri.base;

      if (kIsWeb) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }

      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      final isRecovery = uri.queryParameters['type'] == 'recovery' ||
          uri.fragment.contains('type=recovery');

      if (!mounted) return;

      if (isRecovery) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
        return;
      }

      if (session != null && user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SwipeScreen()),
        );
        return;
      }

      setState(() {
        _message =
        "Email confirmé. Tu peux retourner dans l’application FasoMatch.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Le lien a été ouvert, mais la session n’a pas pu être finalisée.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}