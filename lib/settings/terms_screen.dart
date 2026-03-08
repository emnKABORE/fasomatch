import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalTextScaffold(
      title: 'CGU',
      content: '''
Conditions Générales d’Utilisation – FasoMatch

1. Objet

Les présentes CGU régissent l’utilisation de l’application FasoMatch éditée par FasoMatch SARL.

2. Conditions d’inscription

L’utilisateur doit :
• Être âgé d’au moins 18 ans
• Fournir des informations exactes
• Ne pas usurper l’identité d’un tiers

3. Règles de conduite

Il est strictement interdit :
• Harcèlement
• Usurpation d’identité
• Escroquerie
• Contenu illégal ou non consenti
• Sollicitation financière frauduleuse

4. Suspension

FasoMatch se réserve le droit de suspendre tout compte en cas de violation des CGU.

5. Responsabilité

FasoMatch agit en tant qu’intermédiaire technique.
Les interactions entre utilisateurs relèvent de leur responsabilité.

6. Droit applicable

Les présentes CGU sont soumises au droit burkinabè.
''',
    );
  }
}

class LegalTextScaffold extends StatelessWidget {
  final String title;
  final String content;

  const LegalTextScaffold({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
          ),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}