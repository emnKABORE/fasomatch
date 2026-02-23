import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd1Ctrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _hide1 = true;
  bool _hide2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _pwd1Ctrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewPassword() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.updateUser(
        UserAttributes(password: _pwd1Ctrl.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Mot de passe mis à jour")),
      );

      // Retour au login (ou ta page d’accueil)
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _deco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.75),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999), // ✅ ovale
        borderSide: const BorderSide(color: Colors.black54, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: Colors.black54, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: Color(0xFF1E2DFF), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Nouveau mot de passe",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _pwd1Ctrl,
                          obscureText: _hide1,
                          decoration: _deco("Nouveau mot de passe").copyWith(
                            suffixIcon: IconButton(
                              onPressed: _loading ? null : () => setState(() => _hide1 = !_hide1),
                              icon: Icon(_hide1 ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? "");
                            if (value.isEmpty) return "Mot de passe requis";
                            if (value.length < 6) return "Minimum 6 caractères";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _pwd2Ctrl,
                          obscureText: _hide2,
                          decoration: _deco("Confirmer le mot de passe").copyWith(
                            suffixIcon: IconButton(
                              onPressed: _loading ? null : () => setState(() => _hide2 = !_hide2),
                              icon: Icon(_hide2 ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? "").isEmpty) return "Confirmation requise";
                            if (v != _pwd1Ctrl.text) return "Les mots de passe ne correspondent pas";
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          width: 220,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _saveNewPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2DFF),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF1E2DFF).withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Text(
                              "Valider",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
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