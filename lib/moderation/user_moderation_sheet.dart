import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showUserModerationSheet({
  required BuildContext context,
  required String reportedUserId,
  required String displayedName,
}) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;

  if (currentUser == null) return;
  if (currentUser.id == reportedUserId) return;

  Future<void> blockUser() async {
    try {
      await supabase.from('user_blocks').upsert({
        'blocker_id': currentUser.id,
        'blocked_id': reportedUserId,
      });

      if (!context.mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayedName a été bloqué.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de bloquer cet utilisateur : $e'),
        ),
      );
    }
  }

  Future<void> openReportDialog() async {
    final reasons = const [
      'faux_profil',
      'harcelement',
      'contenu_inapproprie',
      'arnaque_spam',
      'autre',
    ];

    String selectedReason = reasons.first;
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Signaler ce profil',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Motif',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'faux_profil',
                      child: Text('Faux profil'),
                    ),
                    DropdownMenuItem(
                      value: 'harcelement',
                      child: Text('Harcèlement'),
                    ),
                    DropdownMenuItem(
                      value: 'contenu_inapproprie',
                      child: Text('Contenu inapproprié'),
                    ),
                    DropdownMenuItem(
                      value: 'arnaque_spam',
                      child: Text('Arnaque / spam'),
                    ),
                    DropdownMenuItem(
                      value: 'autre',
                      child: Text('Autre'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() => selectedReason = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Détails (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB00020),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Envoyer'),
              ),
            ],
          );
        },
      ),
    ) ??
        false;

    final details = detailsCtrl.text.trim();
    detailsCtrl.dispose();

    if (!confirmed) return;

    try {
      await supabase.from('user_reports').insert({
        'reporter_id': currentUser.id,
        'reported_id': reportedUserId,
        'reason': selectedReason,
        'details': details.isEmpty ? null : details,
        'status': 'open',
      });

      if (!context.mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement envoyé. Merci.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’envoyer le signalement : $e'),
        ),
      );
    }
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFDFDFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayedName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Choisis une action pour protéger ton expérience sur FasoMatch.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _ModerationTile(
              icon: Icons.block,
              title: 'Bloquer',
              subtitle: "Ce profil ne pourra plus interagir avec toi.",
              onTap: blockUser,
            ),
            _ModerationTile(
              icon: Icons.flag_outlined,
              title: 'Signaler',
              subtitle: "Envoyer un signalement à l’équipe FasoMatch.",
              onTap: openReportDialog,
            ),
          ],
        ),
      );
    },
  );
}

class _ModerationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModerationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}