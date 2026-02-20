import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _loading = false;
  String _msg = "";

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _msg = "";
    });

    try {
      final res = await _supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      setState(() {
        _msg = "✅ Signup OK. User: ${res.user?.email}";
      });
    } on AuthException catch (e) {
      setState(() {
        _msg = "❌ Auth error: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _msg = "❌ Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _msg = "";
    });

    try {
      final res = await _supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      setState(() {
        _msg = "✅ Login OK. Session: ${res.session != null}";
      });
    } on AuthException catch (e) {
      setState(() {
        _msg = "❌ Auth error: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _msg = "❌ Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    setState(() {
      _msg = "✅ Logout OK";
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Auth Test (Supabase)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            if (_loading) const CircularProgressIndicator(),

            if (!_loading)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _signup,
                      child: const Text("SIGN UP"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text("LOGIN"),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _logout,
              child: const Text("LOGOUT"),
            ),

            const SizedBox(height: 20),
            Text("User actuel: ${user?.email ?? 'Aucun'}"),
            const SizedBox(height: 10),
            Text(_msg, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}