import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Dates FR (intl)
import 'package:intl/date_symbol_data_local.dart';

// ✅ Android screenshots/recording
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import 'supabase_config.dart';
import 'welcome_screen.dart';
import 'swipe/swipe_screen.dart';
import 'reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ IMPORTANT: initialise la locale FR pour DateFormat('fr_FR')
  await initializeDateFormatting('fr_FR', null);

  // ✅ Android uniquement : blocage screenshots + screen recording
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
      home: const _AuthRouter(),
      routes: {
        '/swipe': (_) => const SwipeScreen(),
      },
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
          event == AuthChangeEvent.signedOut) {
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
    return (session != null) ? const SwipeScreen() : const WelcomeScreen();
  }
}