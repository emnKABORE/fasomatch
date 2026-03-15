import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _busy = false;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _loading = true);

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _reports = [];
          _loading = false;
        });
        return;
      }

      final me = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      final myRole = (me?['role'] ?? 'user').toString();
      if (myRole != 'admin') {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _reports = [];
          _loading = false;
        });
        return;
      }

      final rows = await _supabase
          .from('user_reports')
          .select('''
            id,
            reporter_id,
            reported_id,
            reason,
            details,
            status,
            created_at
          ''')
          .eq('status', 'open')
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _isAdmin = true;
        _reports = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement signalements : $e')),
      );
    }
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'faux_profil':
        return 'Faux profil';
      case 'harcelement':
        return 'Harcèlement';
      case 'contenu_inapproprie':
        return 'Contenu inapproprié';
      case 'arnaque_spam':
        return 'Arnaque / spam';
      default:
        return 'Autre';
    }
  }

  Future<void> _markHandled(Map<String, dynamic> row, String status) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          status == 'handled'
              ? 'Marquer comme traité'
              : 'Rejeter le signalement',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Tu peux ajouter une note interne.",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Note interne (facultatif)',
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
              backgroundColor: status == 'handled'
                  ? const Color(0xFF111111)
                  : const Color(0xFFB00020),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(status == 'handled' ? 'Traité' : 'Rejeter'),
          ),
        ],
      ),
    ) ??
        false;

    final note = noteCtrl.text.trim();
    noteCtrl.dispose();

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('user_reports').update({
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewer_id': currentUser.id,
        'resolution_note': note.isEmpty ? null : note,
      }).eq('id', row['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'handled'
                ? 'Signalement marqué comme traité.'
                : 'Signalement rejeté.',
          ),
        ),
      );

      await _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur traitement signalement : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reportCard(Map<String, dynamic> row) {
    final reason = _reasonLabel((row['reason'] ?? '').toString());
    final details = (row['details'] ?? '').toString().trim();
    final createdAt = (row['created_at'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Reporter ID : ${row['reporter_id']}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Reported ID : ${row['reported_id']}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Signalé le : $createdAt",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                details,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _markHandled(row, 'handled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Traité',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _markHandled(row, 'rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB00020),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Rejeter',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F5FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Admin • Signalements',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Accès refusé. Cette page est réservée aux administrateurs.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      )
          : _reports.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Aucun signalement en attente ✅",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      )
          : Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadReports,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _reports.map(_reportCard).toList(),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}