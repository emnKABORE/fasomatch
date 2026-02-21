import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'welcome_screen.dart'; // ✅ AJOUTE CET IMPORT
// import 'welcome_screen.dart'; // (tu peux laisser commenté pour l’instant)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  debugPrint(
    "✅ Supabase initialisé : ${Supabase.instance.client.auth.currentSession}",
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
        home: const WelcomeScreen(), // ✅ ici (sans double virgule)
    );
  }
}