import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_callback_screen.dart';
import 'biometric_optin_screen.dart';
import 'firebase_options.dart';
import 'reset_password_screen.dart';
import 'supabase_config.dart';
import 'swipe/swipe_screen.dart';
import 'welcome_screen.dart';

const String kWebVapidKey = 'p8ZyDjnsGqAyQBnPgchm7vWZg5Jt1lj0QvWKTDICEpY';
const String kAuthCallbackScheme = 'fasomatch';
const String kAuthCallbackHost = 'auth';
const String kAuthCallbackPath = '/callback';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _fasoMatchChannel = AndroidNotificationChannel(
  'fasomatch_messages',
  'FasoMatch Notifications',
  description: 'Notifications FasoMatch : likes, matchs et messages',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_fasoMatchChannel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initLocalNotifications();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterWindowManager.addFlags(
        FlutterWindowManager.FLAG_SECURE,
      );
    } catch (_) {}
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE63946),
        ),
      ),
      home: const AppPrivacyWrapper(
        child: _AuthRouter(),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/auth/callback') {
          return MaterialPageRoute(
            builder: (_) => const AuthCallbackScreen(),
          );
        }

        if (settings.name == '/swipe') {
          return MaterialPageRoute(
            builder: (_) => const SwipeScreen(),
          );
        }

        return null;
      },
    );
  }
}

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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        if (mounted) {
          setState(() {
            _hideContent = true;
          });
        }
      }

      if (state == AppLifecycleState.resumed) {
        if (mounted) {
          setState(() {
            _hideContent = false;
          });
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
  StreamSubscription<Uri>? _deepLinkSub;
  final AppLinks _appLinks = AppLinks();

  bool _isRecovery = false;
  bool _processingLink = true;

  @override
  void initState() {
    super.initState();
    _listenAuthChanges();
    _listenDeepLinks();
  }

  void _listenAuthChanges() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isRecovery = true;
          _processingLink = false;
        });
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (mounted) {
          setState(() {
            _processingLink = false;
          });
        }
      }
    });
  }

  Future<void> _listenDeepLinks() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() => _processingLink = false);
      }
      return;
    }

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingUri(initialUri);
      } else {
        if (mounted) {
          setState(() => _processingLink = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _processingLink = false);
      }
    }

    _deepLinkSub = _appLinks.uriLinkStream.listen(
          (uri) async {
        await _handleIncomingUri(uri);
      },
      onError: (_) {
        if (mounted) {
          setState(() => _processingLink = false);
        }
      },
    );
  }

  bool _isAuthCallback(Uri uri) {
    return uri.scheme == kAuthCallbackScheme &&
        uri.host == kAuthCallbackHost &&
        uri.path == kAuthCallbackPath;
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    try {
      if (!_isAuthCallback(uri)) {
        if (mounted) {
          setState(() => _processingLink = false);
        }
        return;
      }

      final queryType = uri.queryParameters['type'];
      final hasAccessToken =
          uri.fragment.contains('access_token=') ||
              uri.query.contains('access_token=');

      if (queryType == 'recovery' || uri.fragment.contains('type=recovery')) {
        if (mounted) {
          setState(() {
            _isRecovery = true;
            _processingLink = false;
          });
        }
      }

      if (hasAccessToken || queryType != null) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (e) {
      debugPrint('Deep link auth error: $e');
    } finally {
      if (mounted) {
        setState(() => _processingLink = false);
      }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_processingLink) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isRecovery) {
      return const ResetPasswordScreen();
    }

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

  Future<void> _setOfflineAndSignOut() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'is_online': false,
          'last_seen_at': DateTime.now().toIso8601String(),
          'fcm_token': null,
        }).eq('id', user.id);
      } catch (_) {}
    }

    await _supabase.auth.signOut();
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
        await _setOfflineAndSignOut();
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

  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPresence(true);
    _setupFirebaseMessaging();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundMessageSub?.cancel();
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
    _setPresence(false);
    super.dispose();
  }

  Future<void> _setPresence(bool isOnline) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('profiles').update({
        'is_online': isOnline,
        'last_seen_at': isOnline ? null : DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (_) {}
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      if (kIsWeb) {
        final token = await messaging.getToken(vapidKey: kWebVapidKey);
        await _saveFcmToken(token);

        _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
          await _saveFcmToken(newToken);
        });

        _foregroundMessageSub =
            FirebaseMessaging.onMessage.listen((RemoteMessage message) {});

        _messageOpenedSub =
            FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/swipe', (_) => false);
            });

        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/swipe', (_) => false);
          });
        }

        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      await _saveFcmToken(token);

      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        await _saveFcmToken(newToken);
      });

      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
            final notification = message.notification;
            if (notification == null) return;

            await flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title ?? 'FasoMatch',
              notification.body ?? '',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _fasoMatchChannel.id,
                  _fasoMatchChannel.name,
                  channelDescription: _fasoMatchChannel.description,
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
                iOS: const DarwinNotificationDetails(),
              ),
            );
          });

      _messageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
            if (!mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/swipe', (_) => false);
          });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/swipe', (_) => false);
        });
      }
    } catch (e) {
      debugPrint('FCM setup error: $e');
    }
  }

  Future<void> _saveFcmToken(String? token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token == null || token.trim().isEmpty) return;

    try {
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('FCM save token error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setPresence(true);

      if (kIsWeb || !widget.biometricEnabled) return;

      final pausedAt = _pausedAt;
      if (pausedAt == null) return;

      final elapsed = DateTime.now().difference(pausedAt);
      _pausedAt = null;

      if (elapsed >= relockDelay && mounted) {
        setState(() {
          _showLock = true;
        });
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      _setPresence(false);
    }
  }

  void _unlock() {
    if (!mounted) return;
    setState(() {
      _showLock = false;
    });
  }

  Future<void> _signOutFromLock() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'is_online': false,
          'last_seen_at': DateTime.now().toIso8601String(),
          'fcm_token': null,
        }).eq('id', user.id);
      } catch (_) {}
    }

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
        setState(() {
          _busy = false;
        });
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
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