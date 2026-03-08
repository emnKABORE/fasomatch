import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ReceivedLikeType { like, superlike }
enum ReplyActionType { pass, like, superlike }

class ReceivedLikeModel {
  final String likeId;
  final String fromUserId;
  final String firstName;
  final int age;
  final String city;
  final String? photoUrl;
  final bool isVerified;
  final ReceivedLikeType type;
  final DateTime createdAt;

  const ReceivedLikeModel({
    required this.likeId,
    required this.fromUserId,
    required this.firstName,
    required this.age,
    required this.city,
    required this.photoUrl,
    required this.isVerified,
    required this.type,
    required this.createdAt,
  });
}

class LikesReceivedScreen extends StatefulWidget {
  final String currentPlan;
  final bool has24hLikesAccess;
  final VoidCallback? onUpgradeTap;
  final VoidCallback? onUnlock24hTap;
  final void Function(String matchedUserId, String matchId)? onOpenChat;

  const LikesReceivedScreen({
    super.key,
    required this.currentPlan,
    this.has24hLikesAccess = false,
    this.onUpgradeTap,
    this.onUnlock24hTap,
    this.onOpenChat,
  });

  @override
  State<LikesReceivedScreen> createState() => _LikesReceivedScreenState();
}

class _LikesReceivedScreenState extends State<LikesReceivedScreen> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _processing = false;
  List<ReceivedLikeModel> _likes = [];

  bool get _canAccess =>
      widget.currentPlan == 'premium' ||
          widget.currentPlan == 'ultra' ||
          widget.has24hLikesAccess;

  static const Color _bg = Color(0xFFF6F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _border = Color(0xFFE7E9F2);
  static const Color _text = Colors.black;
  static const Color _muted = Color(0xFF6B7280);

  static const Color _red = Color(0xFFF44336);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _blue = Color(0xFF2196F3);
  static const Color _purple = Color(0xFF7B61FF);
  static const Color _gold = Color(0xFFF4C542);

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  int _computeAge(int? birthYear) {
    if (birthYear == null || birthYear <= 0) return 18;
    final age = DateTime.now().year - birthYear;
    if (age < 18) return 18;
    if (age > 99) return 99;
    return age;
  }

  String? _extractPhoto(Map<String, dynamic> profile) {
    final avatarUrl = profile['avatar_url'];
    if (avatarUrl is String && avatarUrl.trim().isNotEmpty) {
      return avatarUrl.trim();
    }

    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }

    return null;
  }

  Future<void> _loadLikes() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _likes = [];
          _loading = false;
        });
        return;
      }

      final fourteenDaysAgo =
      DateTime.now().subtract(const Duration(days: 14));

      final data = await supabase
          .from('likes')
          .select('''
            id,
            created_at,
            from_user,
            to_user,
            type,
            from_profile:profiles!likes_from_user_fkey(
              id,
              first_name,
              birth_year,
              city,
              avatar_url,
              photos,
              is_verified
            )
          ''')
          .eq('to_user', currentUser.id)
          .gte('created_at', fourteenDaysAgo.toIso8601String())
          .order('created_at', ascending: false);

      final parsed = (data as List)
          .map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        final pRaw = row['from_profile'];
        if (pRaw == null) return null;

        final p = Map<String, dynamic>.from(pRaw as Map);

        return ReceivedLikeModel(
          likeId: row['id'] as String,
          fromUserId: row['from_user'] as String,
          firstName: (p['first_name'] ?? '').toString().trim().isEmpty
              ? 'Utilisateur'
              : p['first_name'].toString().trim(),
          age: _computeAge(p['birth_year'] as int?),
          city: (p['city'] ?? '').toString(),
          photoUrl: _extractPhoto(p),
          isVerified: (p['is_verified'] ?? false) as bool,
          type: row['type'] == 'superlike'
              ? ReceivedLikeType.superlike
              : ReceivedLikeType.like,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      })
          .whereType<ReceivedLikeModel>()
          .toList();

      if (!mounted) return;
      setState(() {
        _likes = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement likes : $e')),
      );
    }
  }

  Future<void> _reply(
      ReceivedLikeModel item,
      ReplyActionType action,
      ) async {
    if (_processing) return;

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final me = currentUser.id;

    setState(() => _processing = true);

    try {
      if (action == ReplyActionType.pass) {
        await supabase.from('likes').delete().eq('id', item.likeId);

        if (!mounted) return;
        setState(() {
          _likes.removeWhere((e) => e.likeId == item.likeId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tu as passé ${item.firstName}')),
        );
        return;
      }

      final replyType =
      action == ReplyActionType.superlike ? 'superlike' : 'like';

      final existingMyLike = await supabase
          .from('likes')
          .select('id')
          .eq('from_user', me)
          .eq('to_user', item.fromUserId)
          .maybeSingle();

      if (existingMyLike == null) {
        await supabase.from('likes').insert({
          'from_user': me,
          'to_user': item.fromUserId,
          'type': replyType,
        });
      }

      final existingMatch = await supabase
          .from('matches')
          .select('id')
          .or(
        'and(user1.eq.$me,user2.eq.${item.fromUserId}),and(user1.eq.${item.fromUserId},user2.eq.$me)',
      )
          .maybeSingle();

      String matchId;

      if (existingMatch == null) {
        final inserted = await supabase
            .from('matches')
            .insert({
          'user1': me,
          'user2': item.fromUserId,
          'last_message_at': DateTime.now().toIso8601String(),
        })
            .select('id')
            .single();

        matchId = inserted['id'] as String;
      } else {
        matchId = existingMatch['id'] as String;
      }

      await supabase.from('likes').delete().eq('id', item.likeId);

      if (!mounted) return;
      setState(() {
        _likes.removeWhere((e) => e.likeId == item.likeId);
      });

      await _showMatchDialog(item, matchId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réponse like : $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _showMatchDialog(
      ReceivedLikeModel item,
      String matchId,
      ) async {
    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: _green,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'C’est un match !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Toi et ${item.firstName} vous vous êtes likés mutuellement.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenChat?.call(item.fromUserId, matchId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Envoyer un message',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Plus tard',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _typeLabel(ReceivedLikeType type) {
    return type == ReceivedLikeType.superlike ? 'Super Like' : 'Like';
  }

  Color _typeColor(ReceivedLikeType type) {
    return type == ReceivedLikeType.superlike ? _blue : _green;
  }

  Widget _buildPhoto(ReceivedLikeModel item) {
    if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          item.photoUrl!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(item),
        ),
      );
    }

    return _buildInitialAvatar(item);
  }

  Widget _buildInitialAvatar(ReceivedLikeModel item) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      alignment: Alignment.center,
      child: Text(
        item.firstName.isNotEmpty
            ? item.firstName.characters.first.toUpperCase()
            : '?',
        style: const TextStyle(
          color: _text,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _buildStatHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: _purple,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_likes.length} like${_likes.length > 1 ? 's' : ''} reçu${_likes.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tu peux répondre aux likes reçus pendant 14 jours.',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeCard(ReceivedLikeModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildPhoto(item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${item.firstName}, ${item.age}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (item.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: _blue,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.city.trim().isEmpty
                          ? 'Ville non renseignée'
                          : item.city,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColor(item.type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _typeColor(item.type).withValues(alpha: 0.26),
                        ),
                      ),
                      child: Text(
                        _typeLabel(item.type),
                        style: TextStyle(
                          color: _typeColor(item.type),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_canAccess) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    color: _red,
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    onTap: _processing
                        ? null
                        : () => _reply(item, ReplyActionType.pass),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    color: _green,
                    icon: Icons.favorite_rounded,
                    label: 'Like',
                    onTap: _processing
                        ? null
                        : () => _reply(item, ReplyActionType.like),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    color: _blue,
                    icon: Icons.star_rounded,
                    label: 'Super',
                    onTap: _processing
                        ? null
                        : () => _reply(item, ReplyActionType.superlike),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          color: Colors.white.withValues(alpha: 0.72),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFC69200),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Réservé Premium & Ultra',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Débloque tes likes pour voir qui t’a liké et répondre par Pass, Like ou Super.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.onUnlock24hTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Débloquer 24h • 1000 F',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.onUpgradeTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Passer Premium',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      toolbarHeight: 122,
      centerTitle: true,
      iconTheme: const IconThemeData(color: _text),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 75,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 75,
              child: Center(
                child: Text(
                  'FasoMatch',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Likes reçus',
            style: TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _purple),
      );
    }

    if (_likes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildStatHeader(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 42,
                  color: _purple,
                ),
                SizedBox(height: 12),
                Text(
                  'Aucun like reçu pour le moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Quand quelqu’un te like, tu le verras ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLikes,
      color: _purple,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildStatHeader(),
          ..._likes.map(_buildLikeCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBody(),
          if (!_canAccess) _buildLockedOverlay(),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}