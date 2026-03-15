import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDeletionScreen extends StatefulWidget {
  const AdminDeletionScreen({super.key});

  @override
  State<AdminDeletionScreen> createState() => _AdminDeletionScreenState();
}

class _AdminDeletionScreenState extends State<AdminDeletionScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _busy = false;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingDeletionRequests();
  }

  Future<void> _loadPendingDeletionRequests() async {
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
            phone,
            deletion_status,
            deletion_reason,
            deletion_requested_at,
            is_active
          ''')
          .eq('deletion_status', 'pending')
          .order('deletion_requested_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _isAdmin = true;
        _requests = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isAdmin = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement suppressions : $e')),
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

  Future<void> _approveDeletion(Map<String, dynamic> row) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Valider la suppression',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Confirmer la suppression définitive du compte de ${_fullName(row)} ?',
          style: const TextStyle(fontWeight: FontWeight.w600),
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
            child: const Text('Valider'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      final response = await _supabase.functions.invoke(
        'delete-user-account',
        body: {
          'user_id': row['id'],
        },
      );

      if (response.status != 200) {
        throw Exception(response.data.toString());
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_fullName(row)} supprimé définitivement ✅'),
        ),
      );

      await _loadPendingDeletionRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression définitive : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectDeletion(Map<String, dynamic> row) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Annuler la demande',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Annuler la demande de suppression de ${_fullName(row)} ?',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('profiles').update({
        'deletion_status': 'none',
        'deletion_requested_at': null,
        'deletion_reason': null,
        'deleted_at': null,
        'deletion_reviewed_at': DateTime.now().toIso8601String(),
        'deletion_reviewer_id': currentUser.id,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', row['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demande de suppression annulée pour ${_fullName(row)}.',
          ),
        ),
      );

      await _loadPendingDeletionRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur annulation suppression : $e')),
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
    final fullName = _fullName(row);
    final city = (row['city'] ?? '').toString().trim();
    final requestedAt = (row['deletion_requested_at'] ?? '').toString().trim();
    final reason = (row['deletion_reason'] ?? '').toString().trim();
    final phone = (row['phone'] ?? '').toString().trim();

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
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Téléphone : $phone',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (requestedAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Demandé le : $requestedAt',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Motif : $reason',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _approveDeletion(row),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB00020),
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
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _rejectDeletion(row),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Annuler la demande',
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
          'Admin • Suppression comptes',
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
            "Aucune demande de suppression en attente ✅",
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
            onRefresh: _loadPendingDeletionRequests,
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