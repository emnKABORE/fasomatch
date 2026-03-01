import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conversations = _fakeConversations;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Matches',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = conversations[i];

          return _ConversationTile(
            convo: c,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(conversation: c),
                ),
              );
            },
          );
        },
      ),
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            _AvatarWithOnlineDot(
              imagePath: convo.avatarPath,
              isOnline: convo.isOnline,
              size: 52,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : prénom + heure
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        convo.isToday ? time : date,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Ligne 2 : aperçu + lu/non lu + badge
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
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE63946),
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
            Icon(Icons.chevron_right_rounded,
                color: Colors.black.withOpacity(0.25)),
          ],
        ),
      ),
    );
  }
}

class _AvatarWithOnlineDot extends StatelessWidget {
  final String imagePath;
  final bool isOnline;
  final double size;

  const _AvatarWithOnlineDot({
    required this.imagePath,
    required this.isOnline,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 24),
            ),
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

enum ReadStatus { none, sent, delivered, read }

class _ReadReceiptMini extends StatelessWidget {
  final ReadStatus status;
  final bool isFromMe;

  const _ReadReceiptMini({
    required this.status,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    // Si le dernier message vient de l’autre, on ne met pas de ✓✓
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
        color = const Color(0xFF2563EB); // bleu façon iMessage
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

// ----------------- MODELS (pour brancher Supabase ensuite) -----------------

class ConversationPreview {
  final String id;
  final String name;
  final String avatarPath;
  final bool isOnline;

  final String lastMessageText;
  final DateTime lastMessageAt;

  final bool lastMessageFromMe;
  final ReadStatus lastMessageReadStatus;

  final int unreadCount;

  const ConversationPreview({
    required this.id,
    required this.name,
    required this.avatarPath,
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

// Fake data (à remplacer par Supabase)
final _fakeConversations = <ConversationPreview>[
  ConversationPreview(
    id: '1',
    name: 'Aïcha',
    avatarPath: 'assets/images/sample_profile_1.jpg',
    isOnline: true,
    lastMessageText: 'On se parle ce soir ? 🙂',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 9)),
    lastMessageFromMe: false,
    lastMessageReadStatus: ReadStatus.none,
    unreadCount: 2,
  ),
  ConversationPreview(
    id: '2',
    name: 'Nina',
    avatarPath: 'assets/images/sample_profile_2.jpg',
    isOnline: false,
    lastMessageText: 'Tu es où à Ouaga ?',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
    lastMessageFromMe: true,
    lastMessageReadStatus: ReadStatus.read,
    unreadCount: 0,
  ),
  ConversationPreview(
    id: '3',
    name: 'Moussa',
    avatarPath: 'assets/images/sample_profile_3.jpg',
    isOnline: true,
    lastMessageText: 'Hello !',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
    lastMessageFromMe: true,
    lastMessageReadStatus: ReadStatus.delivered,
    unreadCount: 0,
  ),
];