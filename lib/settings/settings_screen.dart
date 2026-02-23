import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final String currentPlan;
  final VoidCallback onUpgradeTap;

  const SettingsScreen({
    super.key,
    required this.currentPlan,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        elevation: 0,
        title: const Text("Paramètres",
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.black12,
                  child: Icon(Icons.person, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Mon compte",
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text("Abonnement : $currentPlan",
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onUpgradeTap,
                  child: const Text("Upgrade"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _sectionTitle("Profil"),
          _tile(
            icon: Icons.verified_outlined,
            title: "Vérifier mon profil",
            subtitle: "Badge vérifié (KYC / selfie / doc plus tard)",
            onTap: () => _snack(context, "📌 Vérification (à brancher)"),
          ),
          _tile(
            icon: Icons.edit_outlined,
            title: "Modifier mon profil",
            subtitle: "Photos, bio, infos",
            onTap: () => _snack(context, "📌 Édition profil (à brancher)"),
          ),

          const SizedBox(height: 12),
          _sectionTitle("Sécurité"),
          _tile(
            icon: Icons.lock_outline,
            title: "Changer le mot de passe",
            subtitle: "Renforcer la sécurité",
            onTap: () => _snack(context, "📌 Changement MDP (à brancher)"),
          ),
          _tile(
            icon: Icons.fingerprint,
            title: "Connexion biométrique",
            subtitle: "FaceID / TouchID",
            onTap: () => _snack(context, "📌 Biométrie (à brancher)"),
          ),

          const SizedBox(height: 12),
          _sectionTitle("Conformité & confidentialité"),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: "Politique de confidentialité",
            subtitle: "Lire",
            onTap: () => _snack(context, "📌 Page politique (à brancher)"),
          ),
          _tile(
            icon: Icons.description_outlined,
            title: "CGU",
            subtitle: "Lire",
            onTap: () => _snack(context, "📌 Page CGU (à brancher)"),
          ),
          _tile(
            icon: Icons.download_outlined,
            title: "Télécharger mes données",
            subtitle: "Droit d’accès (RGPD)",
            onTap: () => _snack(context, "📌 Export données (à brancher)"),
          ),
          _tile(
            icon: Icons.delete_forever_outlined,
            title: "Supprimer mon compte",
            subtitle: "Droit à l’effacement",
            onTap: () => _snack(context, "📌 Suppression compte (à brancher)"),
          ),

          const SizedBox(height: 12),
          _sectionTitle("Support"),
          _tile(
            icon: Icons.help_outline,
            title: "Centre d’aide",
            subtitle: "FAQ / Assistance",
            onTap: () => _snack(context, "📌 Support (à brancher)"),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
    ),
    child: child,
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}