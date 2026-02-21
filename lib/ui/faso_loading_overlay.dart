import 'package:flutter/material.dart';

/// Overlay de chargement (logo + message) utilisable de 2 façons :
/// 1) En wrapper widget : FasoLoadingOverlay(isLoading: true/false, child: ...)
/// 2) En helper async : await FasoLoadingOverlay.run(context, action: () async { ... }, message: "...")
class FasoLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String message;

  const FasoLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = "Chargement...",
  });

  /// ✅ Version "helper" pour afficher un overlay pendant une action async
  /// Utilisation :
  /// await FasoLoadingOverlay.run(
  ///   context,
  ///   action: () async { ... },
  ///   message: "Connexion...",
  /// );
  static Future<T?> run<T>(
      BuildContext context, {
        required Future<T> Function() action,
        String message = "Chargement...",
      }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) {
      // Si pas d'overlay (rare), on exécute quand même l'action
      return await action();
    }

    final entry = OverlayEntry(
      builder: (_) => _LoadingLayer(message: message),
    );

    overlay.insert(entry);

    try {
      return await action();
    } finally {
      entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) const _LoadingLayer(),
      ],
    );
  }
}

class _LoadingLayer extends StatelessWidget {
  final String message;

  const _LoadingLayer({this.message = "Chargement..."});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.25),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 10),
                  color: Color(0x22000000),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // petit “blink” simple via AnimatedOpacity
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.35, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOut,
                  builder: (context, v, child) {
                    return Opacity(
                      opacity: v,
                      child: child,
                    );
                  },
                  onEnd: () {},
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 70,
                        height: 70,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
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