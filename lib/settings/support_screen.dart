import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String email = 'contact@fasomatch.app';
  static const String whatsapp = '+22644071346';

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:$email?subject=Support FasoMatch&body=Bonjour, j’ai besoin d’aide concernant mon compte FasoMatch.',
    );

    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir l’email.")),
      );
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final phone = whatsapp.replaceAll('+', '').replaceAll(' ', '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent("Bonjour, j’ai besoin d’aide concernant FasoMatch.")}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir WhatsApp.")),
      );
    }
  }

  Widget _supportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        title: const Text(
          "Centre d’aide",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _supportCard(
              icon: Icons.email_outlined,
              title: "Nous écrire par email",
              subtitle: email,
              onTap: () => _launchEmail(context),
            ),
            const SizedBox(height: 12),
            _supportCard(
              icon: Icons.message_outlined,
              title: "Nous contacter sur WhatsApp",
              subtitle: whatsapp,
              onTap: () => _launchWhatsApp(context),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                "Notre équipe support peut vous aider pour les problèmes de compte, d’abonnement, de sécurité, de vérification de profil et d’accès à l’application.",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}