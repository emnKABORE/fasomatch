import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'matches_screen.dart'; // important : même dossier

class ChatScreen extends StatefulWidget {
  final ConversationPreview conversation;

  const ChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();

    _messages = [
      ChatMessage(
        id: '1',
        text: 'Salut 👋',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        fromMe: false,
        status: ReadStatus.none,
      ),
      ChatMessage(
        id: '2',
        text: 'On fait connaissance ?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 19)),
        fromMe: false,
        status: ReadStatus.none,
      ),
      ChatMessage(
        id: '3',
        text: 'Coucou 🙂',
        createdAt: DateTime.now().subtract(const Duration(minutes: 17)),
        fromMe: true,
        status: ReadStatus.read,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      createdAt: DateTime.now(),
      fromMe: true,
      status: ReadStatus.sent,
    );

    setState(() {
      _messages.add(message);
    });

    _controller.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final convo = widget.conversation;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _AvatarWithOnline(
              imagePath: convo.avatarPath,
              isOnline: convo.isOnline,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  convo.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  convo.isOnline ? "En ligne" : "Hors ligne",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final previous =
                index == 0 ? null : _messages[index - 1];

                final showDate = previous == null ||
                    !_sameDay(previous.createdAt, message.createdAt);

                return Column(
                  children: [
                    if (showDate)
                      _DateSeparator(date: message.createdAt),
                    _MessageBubble(message: message),
                  ],
                );
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Message…",
                    border: InputBorder.none,
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Icon(Icons.send_rounded, size: 20),
              ),
            )
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.fromMe;
    final time = DateFormat.Hm().format(message.createdAt);

    return Align(
      alignment:
      isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF2563EB)
              : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white70
                        : Colors.black45,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Text(
                    message.status == ReadStatus.read
                        ? "✓✓"
                        : message.status ==
                        ReadStatus.delivered
                        ? "✓✓"
                        : message.status ==
                        ReadStatus.sent
                        ? "✓"
                        : "",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: message.status ==
                          ReadStatus.read
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AvatarWithOnline extends StatelessWidget {
  final String imagePath;
  final bool isOnline;

  const _AvatarWithOnline({
    required this.imagePath,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Image.asset(
            imagePath,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF22C55E)
                  : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final label =
    DateFormat('EEEE dd MMM', 'fr_FR').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool fromMe;
  final ReadStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.fromMe,
    required this.status,
  });
}