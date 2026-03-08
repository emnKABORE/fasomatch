import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  List<ConversationPreview> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
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

  Future<void> _loadConversations() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }

      final rows = await supabase
          .from('matches')
          .select('id, user1, user2, created_at, last_message_at')
          .or('user1.eq.${currentUser.id},user2.eq.${currentUser.id}')
          .order('last_message_at', ascending: false);

      final parsed = await Future.wait(
        (rows as List).map((e) async {
          final row = Map<String, dynamic>.from(e as Map);
          final matchId = row['id'] as String;
          final user1 = row['user1'] as String;
          final user2 = row['user2'] as String;
          final otherUserId = user1 == currentUser.id ? user2 : user1;

          final profileRaw = await supabase
              .from('profiles')
              .select('id, first_name, avatar_url, photos')
              .eq('id', otherUserId)
              .maybeSingle();

          final profile = profileRaw == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(profileRaw as Map);

          final lastMessageRaw = await supabase
              .from('messages')
              .select('id, author_id, content, created_at, is_read')
              .eq('match_id', matchId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          final unreadRows = await supabase
              .from('messages')
              .select('id')
              .eq('match_id', matchId)
              .neq('author_id', currentUser.id)
              .eq('is_read', false);

          final unreadCount = (unreadRows as List).length;

          if (lastMessageRaw == null) {
            final date = row['last_message_at'] != null
                ? DateTime.parse(row['last_message_at'] as String)
                : DateTime.parse(row['created_at'] as String);

            return ConversationPreview(
              id: matchId,
              otherUserId: otherUserId,
              name: (profile['first_name'] ?? 'Match').toString(),
              avatarUrl: _extractPhoto(profile),
              isOnline: false,
              lastMessageText: 'Commence la conversation ✨',
              lastMessageAt: date,
              lastMessageFromMe: false,
              lastMessageReadStatus: ReadStatus.none,
              unreadCount: 0,
            );
          }

          final lastMessage = Map<String, dynamic>.from(lastMessageRaw as Map);
          final lastMessageFromMe = lastMessage['author_id'] == currentUser.id;

          return ConversationPreview(
            id: matchId,
            otherUserId: otherUserId,
            name: (profile['first_name'] ?? 'Match').toString(),
            avatarUrl: _extractPhoto(profile),
            isOnline: false,
            lastMessageText: (lastMessage['content'] ?? '').toString(),
            lastMessageAt: DateTime.parse(lastMessage['created_at'] as String),
            lastMessageFromMe: lastMessageFromMe,
            lastMessageReadStatus:
            lastMessage['is_read'] == true && lastMessageFromMe
                ? ReadStatus.read
                : lastMessageFromMe
                ? ReadStatus.sent
                : ReadStatus.none,
            unreadCount: unreadCount,
          );
        }),
      );

      if (!mounted) return;
      setState(() {
        _conversations = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement matches : $e')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF6F7FB),
      surfaceTintColor: const Color(0xFFF6F7FB),
      elevation: 0,
      toolbarHeight: 122,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.black,
          size: 26,
        ),
        onPressed: () => Navigator.pop(context),
      ),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Matches',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E9F2)),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7B61FF).withOpacity(0.12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFF7B61FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_conversations.length} match${_conversations.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_conversations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        children: [
          _buildStatsHeader(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7E9F2)),
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
                  Icons.chat_bubble_outline_rounded,
                  size: 42,
                  color: Color(0xFF2563EB),
                ),
                SizedBox(height: 12),
                Text(
                  'Aucun match pour le moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Quand un match sera créé, il apparaîtra ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
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
      onRefresh: _loadConversations,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        itemCount: _conversations.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _buildStatsHeader();

          final c = _conversations[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ConversationTile(
              convo: c,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(conversation: c),
                  ),
                );
                _loadConversations();
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationPreview convo;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.convo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(convo.lastMessageAt);
    final date = DateFormat('dd/MM').format(convo.lastMessageAt);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7E9F2)),
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
            _AvatarWithOnlineDot(
              imageUrl: convo.avatarUrl,
              name: convo.name,
              isOnline: convo.isOnline,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          convo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        convo.isToday ? time : date,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ReadReceiptMini(
                        status: convo.lastMessageReadStatus,
                        isFromMe: convo.lastMessageFromMe,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          convo.lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: convo.unreadCount > 0
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (convo.unreadCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            convo.unreadCount > 99
                                ? '99+'
                                : '${convo.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWithOnlineDot extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isOnline;
  final double size;

  const _AvatarWithOnlineDot({
    required this.imageUrl,
    required this.name,
    required this.isOnline,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
            imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _FallbackAvatar(
              size: size,
              initial: initial,
            ),
          )
              : _FallbackAvatar(
            size: size,
            initial: initial,
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF22C55E) : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final double size;
  final String initial;

  const _FallbackAvatar({
    required this.size,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF2F8),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ReadReceiptMini extends StatelessWidget {
  final ReadStatus status;
  final bool isFromMe;

  const _ReadReceiptMini({
    required this.status,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFromMe) return const SizedBox(width: 0);

    String symbol = '';
    Color color = Colors.black.withOpacity(0.35);

    switch (status) {
      case ReadStatus.none:
        symbol = '';
        break;
      case ReadStatus.sent:
        symbol = '✓';
        break;
      case ReadStatus.delivered:
        symbol = '✓✓';
        break;
      case ReadStatus.read:
        symbol = '✓✓';
        color = const Color(0xFF2563EB);
        break;
    }

    if (symbol.isEmpty) return const SizedBox(width: 0);

    return Text(
      symbol,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );
  }
}

enum ReadStatus {
  none,
  sent,
  delivered,
  read,
}

class ConversationPreview {
  final String id;
  final String otherUserId;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final bool lastMessageFromMe;
  final ReadStatus lastMessageReadStatus;
  final int unreadCount;

  const ConversationPreview({
    required this.id,
    required this.otherUserId,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastMessageText,
    required this.lastMessageAt,
    required this.lastMessageFromMe,
    required this.lastMessageReadStatus,
    required this.unreadCount,
  });

  bool get isToday {
    final now = DateTime.now();
    return now.year == lastMessageAt.year &&
        now.month == lastMessageAt.month &&
        now.day == lastMessageAt.day;
  }
}