import 'package:flutter/material.dart';
import 'legal_links.dart';
import 'open_url.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Infos légales')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Politique de confidentialité'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openUrl(LegalLinks.privacy),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Conditions Générales d’Utilisation (CGU)'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openUrl(LegalLinks.cgu),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Mentions légales'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openUrl(LegalLinks.legal),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Ces documents s’ouvrent dans votre navigateur.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}