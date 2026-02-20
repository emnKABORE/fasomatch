import 'dart:async';
import 'package:flutter/material.dart';
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

    // ✅ Animation "clignotement" sur 5 secondes
    // On va faire 5 cycles (1 par seconde)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // répète 5 fois pendant 5 secondes
    _controller.repeat(reverse: true);

    // arrêt au bout de 5 secondes (sinon ça continue)
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _controller.stop();
    });

    // ✅ Redirection après 5 secondes
    _redirectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
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
    // ✅ On fait "blanc <-> normal" en alternance
    // value proche de 1 = très blanc
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/images/intro.png', fit: BoxFit.cover),

          // Overlay sombre
          Container(color: Colors.black.withOpacity(0.45)),

          // Contenu
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Logo qui clignote en blanc
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // on mélange blanc/normal
                      final t = _controller.value; // 0..1
                      return ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Color.lerp(Colors.transparent, Colors.white, t)!,
                          BlendMode.modulate,
                        ),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 140,
                    ),
                  ),

                  const SizedBox(height: 18),

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
