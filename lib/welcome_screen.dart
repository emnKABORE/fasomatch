import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();

    // 🔥 Animation halo (respiration douce)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // ✅ Redirection après 5 secondes
    _redirectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/swipe', (_) => false);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🔹 Background image
          Image.asset(
            'assets/images/intro.png',
            fit: BoxFit.cover,
          ),

          // 🔹 Overlay sombre
          Container(
            color: Colors.black.withOpacity(0.45),
          ),

          // 🔹 Contenu central
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = _controller.value;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 🔥 Halo lumineux blanc animé
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4 + (t * 0.4)),
                                  blurRadius: 40 + (t * 40),
                                  spreadRadius: 5 + (t * 10),
                                ),
                              ],
                            ),
                          ),

                          // ✅ Logo fixe
                          Image.asset(
                            'assets/images/logo.png',
                            width: 140,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    "🚀 Bienvenue sur FasoMatch",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Votre appli de rencontre souveraine",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}