import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import 'supabase_config.dart';
import 'welcome_screen.dart';
import 'swipe/swipe_screen.dart';
import 'reset_password_screen.dart';
import 'biometric_optin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR', null);

  // ✅ Blocage global screenshots / enregistrement Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const FasoMatchApp());
}

class FasoMatchApp extends StatelessWidget {
  const FasoMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FasoMatch',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE63946)),
      ),
      home: const AppPrivacyWrapper(
        child: _AuthRouter(),
      ),
      routes: {
        '/swipe': (_) => const SwipeScreen(),
      },
    );
  }
}

/// ✅ Overlay global pour masquer le contenu sur iPhone
class AppPrivacyWrapper extends StatefulWidget {
  final Widget child;

  const AppPrivacyWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AppPrivacyWrapper> createState() => _AppPrivacyWrapperState();
}

class _AppPrivacyWrapperState extends State<AppPrivacyWrapper>
    with WidgetsBindingObserver {
  bool _hideContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        if (mounted) {
          setState(() => _hideContent = true);
        }
      }

      if (state == AppLifecycleState.resumed) {
        if (mounted) {
          setState(() => _hideContent = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_hideContent)
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/fasomatch_logo.png',
                  width: 75,
                  height: 75,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.lock,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Contenu protégé',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AuthRouter extends StatefulWidget {
  const _AuthRouter();

  @override
  State<_AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<_AuthRouter> {
  late final StreamSubscription<AuthState> _sub;
  bool _isRecovery = false;

  @override
  void initState() {
    super.initState();

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() => _isRecovery = true);
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecovery) return const ResetPasswordScreen();

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const WelcomeScreen();
    }

    return const _SessionEntryGate();
  }
}

class _SessionEntryGate extends StatefulWidget {
  const _SessionEntryGate();

  @override
  State<_SessionEntryGate> createState() => _SessionEntryGateState();
}

class _SessionEntryGateState extends State<_SessionEntryGate> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _requiresBiometric = false;
  bool _promptSeen = false;
  String _biometricPreference = 'auto';

  @override
  void initState() {
    super.initState();
    _loadBiometricRequirement();
  }

  Future<void> _loadBiometricRequirement() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _requiresBiometric = false;
          _promptSeen = true;
          _loading = false;
        });
        return;
      }

      final row = await _supabase
          .from('profiles')
          .select(
        'biometric_enabled, biometric_preference, biometric_prompt_seen',
      )
          .eq('id', user.id)
          .maybeSingle();

      final enabled = (row?['biometric_enabled'] as bool?) ?? false;
      final preference = (row?['biometric_preference'] ?? 'auto').toString();
      final promptSeen = (row?['biometric_prompt_seen'] as bool?) ?? false;

      if (!mounted) return;
      setState(() {
        _requiresBiometric = enabled && !kIsWeb;
        _biometricPreference = preference;
        _promptSeen = promptSeen;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requiresBiometric = false;
        _promptSeen = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_promptSeen) {
      return const BiometricOptinScreen();
    }

    if (!_requiresBiometric) {
      return const AppGuard(
        biometricEnabled: false,
        biometricPreference: 'auto',
        child: SwipeScreen(),
      );
    }

    return BiometricLockScreen(
      biometricPreference: _biometricPreference,
      onAuthenticated: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppGuard(
              biometricEnabled: true,
              biometricPreference: _biometricPreference,
              child: const SwipeScreen(),
            ),
          ),
        );
      },
      onSignOut: () async {
        await _supabase.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
        );
      },
    );
  }
}

class AppGuard extends StatefulWidget {
  final Widget child;
  final bool biometricEnabled;
  final String biometricPreference;

  const AppGuard({
    super.key,
    required this.child,
    required this.biometricEnabled,
    required this.biometricPreference,
  });

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _showLock = false;

  static const Duration relockDelay = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !widget.biometricEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      if (pausedAt == null) return;

      final elapsed = DateTime.now().difference(pausedAt);
      _pausedAt = null;

      if (elapsed >= relockDelay && mounted) {
        setState(() => _showLock = true);
      }
    }
  }

  void _unlock() {
    if (!mounted) return;
    setState(() => _showLock = false);
  }

  Future<void> _signOutFromLock() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showLock) {
      return BiometricLockScreen(
        biometricPreference: widget.biometricPreference,
        onAuthenticated: _unlock,
        onSignOut: _signOutFromLock,
      );
    }

    return widget.child;
  }
}

class BiometricLockScreen extends StatefulWidget {
  final String biometricPreference;
  final VoidCallback onAuthenticated;
  final Future<void> Function() onSignOut;

  const BiometricLockScreen({
    super.key,
    required this.biometricPreference,
    required this.onAuthenticated,
    required this.onSignOut,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _localAuth = LocalAuthentication();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  String _methodLabel() {
    switch (widget.biometricPreference) {
      case 'fingerprint':
        return 'empreinte digitale';
      case 'face':
        return 'reconnaissance faciale';
      default:
        return 'biométrie';
    }
  }

  Future<void> _authenticate() async {
    if (kIsWeb) {
      widget.onAuthenticated();
      return;
    }

    try {
      setState(() {
        _busy = true;
        _error = null;
      });

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        setState(() {
          _error = "La biométrie n’est pas disponible sur cet appareil.";
        });
        return;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        setState(() {
          _error = "Aucune biométrie n’est configurée sur cet appareil.";
        });
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason:
        'Authentifie-toi avec ${_methodLabel()} pour accéder à FasoMatch',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (ok) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _error = "Authentification annulée.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Erreur biométrique : $e";
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F5FF);
    const blush = Color(0xFFFFE5E8);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/fasomatch_logo.png',
                    width: 75,
                    height: 75,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.favorite,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Accès sécurisé",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Authentifie-toi avec ${_methodLabel()} pour ouvrir FasoMatch.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: blush,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.black87,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _busy ? "Vérification..." : "Réessayer",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : widget.onSignOut,
                    child: const Text(
                      "Se déconnecter",
                      style: TextStyle(fontWeight: FontWeight.w800),
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