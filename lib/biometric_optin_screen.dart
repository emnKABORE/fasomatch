import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/app_colors.dart';
import 'ui/primary_button.dart';
import 'ui/app_logo.dart';

class BiometricOptinScreen extends StatefulWidget {
  const BiometricOptinScreen({super.key});

  @override
  State<BiometricOptinScreen> createState() => _BiometricOptinScreenState();
}

class _BiometricOptinScreenState extends State<BiometricOptinScreen> {
  final _supabase = Supabase.instance.client;
  final _localAuth = LocalAuthentication();

  bool _busy = false;

  void _goSwipe(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/swipe');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveBiometricChoice({
    required bool enabled,
    required String preference,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'biometric_enabled': enabled,
      'biometric_preference': preference,
      'biometric_prompt_seen': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> _skipForNow() async {
    try {
      setState(() => _busy = true);

      await _saveBiometricChoice(
        enabled: false,
        preference: 'auto',
      );

      if (!mounted) return;
      _goSwipe(context);
    } catch (e) {
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showBiometricMethodPicker() async {
    if (kIsWeb) {
      _snack(
        "La biométrie n’est pas disponible sur Chrome Web. Active-la plus tard depuis Android ou iPhone.",
      );
      await _skipForNow();
      return;
    }

    try {
      setState(() => _busy = true);

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        _snack("La biométrie n’est pas disponible sur cet appareil.");
        await _skipForNow();
        return;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        _snack("Aucune biométrie n’est configurée sur cet appareil.");
        await _skipForNow();
        return;
      }

      if (!mounted) return;
      setState(() => _busy = false);

      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFDFDFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Choisis ta méthode",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tu pourras modifier ce choix plus tard dans les paramètres.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _methodTile(
                  icon: Icons.fingerprint,
                  title: "Empreinte digitale",
                  subtitle: "Connexion rapide par empreinte",
                  onTap: () => Navigator.pop(context, 'fingerprint'),
                ),
                _methodTile(
                  icon: Icons.face_outlined,
                  title: "Reconnaissance faciale",
                  subtitle: "Connexion rapide par visage",
                  onTap: () => Navigator.pop(context, 'face'),
                ),
                _methodTile(
                  icon: Icons.smartphone_outlined,
                  title: "Automatique",
                  subtitle: "L’appareil choisira la meilleure méthode",
                  onTap: () => Navigator.pop(context, 'auto'),
                ),
              ],
            ),
          );
        },
      );

      if (selected == null) return;

      setState(() => _busy = true);

      final authenticated = await _localAuth.authenticate(
        localizedReason:
        'Confirme l’activation de la connexion biométrique pour FasoMatch',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        _snack("Activation biométrique annulée.");
        return;
      }

      await _saveBiometricChoice(
        enabled: true,
        preference: selected,
      );

      if (!mounted) return;
      _goSwipe(context);
    } on MissingPluginException {
      _snack(
        "Plugin biométrique indisponible. Relance complètement l’app sur Android ou iPhone.",
      );
      if (mounted) {
        _goSwipe(context);
      }
    } catch (e) {
      _snack("Erreur biométrique : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Widget _methodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
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
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Center(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Souhaites-tu te connecter plus vite la prochaine fois avec ton empreinte ou la reconnaissance faciale ?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      text: "Oui, activer",
                      width: 220,
                      height: 44,
                      onPressed: _busy ? null : _showBiometricMethodPicker,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _skipForNow,
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
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}