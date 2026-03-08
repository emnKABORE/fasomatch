import 'package:flutter/material.dart';
import 'terms_screen.dart';

class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalTextScaffold(
      title: 'Mentions légales',
      content: '''
MENTIONS LÉGALES – Version conforme Burkina

Éditeur :

FasoMatch SARL
IFU : 00295020Z
RCCM : BF-OUA-01-2025-B13-20320
Siège social : Ouagadougou, Burkina Faso
Email : support@fasomatch.app

Directrice de publication : Diane KAMBOU

Hébergement :

Supabase Inc.
Serveurs situés dans l’Union Européenne (Allemagne)
''',
    );
  }
}