import 'package:flutter/material.dart';
import 'terms_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalTextScaffold(
      title: 'Politique de confidentialité',
      content: '''
Politique de confidentialité – FasoMatch

Dernière mise à jour : 27/02/2026

1. Responsable du traitement

La société FasoMatch SARL
Identifiant Financier Unique (IFU) : 00295020Z
RCCM : BF-OUA-01-2025-B13-20320
Siège : Ouagadougou, Burkina Faso
Email : support@fasomatch.app

est responsable du traitement des données personnelles collectées via l’application FasoMatch.

2. Données collectées

FasoMatch peut collecter :
• Adresse email
• Pseudonyme
• Date de naissance
• Ville
• Photos
• Messages échangés
• Données techniques (IP, logs de connexion)

3. Finalités

Les données sont traitées pour :
• Gestion des comptes utilisateurs
• Mise en relation
• Sécurisation de la plateforme
• Prévention des fraudes
• Respect des obligations légales

4. Base légale

Les traitements reposent sur :
• L’exécution contractuelle (CGU)
• Le consentement de l’utilisateur
• L’intérêt légitime de sécurisation

5. Conservation

Les données sont conservées :
• Pendant la durée d’utilisation du compte
• Jusqu’à 12 mois après suppression
• Selon les obligations légales applicables

6. Hébergement

Les données sont hébergées par Supabase (Union Européenne).

7. Droits des utilisateurs

Conformément aux réglementations applicables, l’utilisateur dispose :
• Droit d’accès
• Droit de rectification
• Droit d’effacement
• Droit d’opposition
• Droit à la limitation

Toute demande peut être adressée à :
support@fasomatch.app
''',
    );
  }
}