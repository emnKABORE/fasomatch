import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _busy = false;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    try {
      setState(() => _loading = true);

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _requests = [];
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
          _requests = [];
          _loading = false;
        });
        return;
      }

      final rows = await _supabase
          .from('profiles')
          .select('''
            id,
            first_name,
            last_name,
            city,
            avatar_url,
            verification_status,
            verification_document_type,
            verification_document_url,
            verification_document_path,
            verification_submitted_at,
            is_verified
          ''')
          .eq('verification_status', 'en_attente')
          .order('verification_submitted_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _isAdmin = true;
        _requests = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement KYC : $e')),
      );
    }
  }

  String _fullName(Map<String, dynamic> row) {
    final first = (row['first_name'] ?? '').toString().trim();
    final last = (row['last_name'] ?? '').toString().trim();

    if (first.isEmpty && last.isEmpty) return 'Utilisateur';
    if (last.isEmpty) return first;
    if (first.isEmpty) return last;
    return '$first $last';
  }

  String _docTypeLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'carte_id':
        return 'Carte d’identité';
      case 'passeport':
        return 'Passeport';
      default:
        return 'Document';
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> row) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Valider ce profil',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Confirmer la vérification du profil de ${_fullName(row)} ?',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('profiles').update({
        'verification_status': 'verifie',
        'is_verified': true,
        'verified_at': DateTime.now().toIso8601String(),
        'verification_reviewed_at': DateTime.now().toIso8601String(),
        'verification_reviewer_id': currentUser.id,
        'verification_reject_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', row['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_fullName(row)} a été vérifié ✅'),
        ),
      );

      await _loadPendingRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur validation : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> row) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Refuser cette vérification',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tu peux indiquer un motif de refus pour ${_fullName(row)}.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Motif du refus (facultatif)',
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
            child: const Text('Refuser'),
          ),
        ],
      ),
    ) ??
        false;

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('profiles').update({
        'verification_status': 'refuse',
        'is_verified': false,
        'verification_reviewed_at': DateTime.now().toIso8601String(),
        'verification_reviewer_id': currentUser.id,
        'verification_reject_reason': reason.isEmpty ? null : reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', row['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_fullName(row)} a été refusé.'),
        ),
      );

      await _loadPendingRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur refus : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _avatar(String? url) {
    final clean = (url ?? '').trim();

    if (clean.isEmpty) {
      return const CircleAvatar(
        radius: 26,
        child: Icon(Icons.person),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: NetworkImage(clean),
      onBackgroundImageError: (_, __) {},
      child: clean.isEmpty ? const Icon(Icons.person) : null,
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final docUrl = (row['verification_document_url'] ?? '').toString().trim();
    final fullName = _fullName(row);
    final city = (row['city'] ?? '').toString().trim();
    final docType = _docTypeLabel(row['verification_document_type']?.toString());
    final submittedAt =
    (row['verification_submitted_at'] ?? '').toString().trim();

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
        children: [
          Row(
            children: [
              _avatar(row['avatar_url']?.toString()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      city.isEmpty ? 'Ville non renseignée' : city,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      docType,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (submittedAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Soumis le : $submittedAt',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (docUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                docUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 160,
                    color: Colors.grey.shade100,
                    alignment: Alignment.center,
                    child: const Text(
                      'Impossible de charger le document',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Aucun aperçu disponible',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _approveRequest(row),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Valider',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _rejectRequest(row),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB00020),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Refuser',
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
          'Admin • Vérification profils',
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
          : _requests.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Aucune demande de vérification en attente ✅",
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
            onRefresh: _loadPendingRequests,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _requests.map(_requestCard).toList(),
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