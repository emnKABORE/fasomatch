import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/security_service.dart';
import 'matches_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationPreview conversation;

  const ChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  final security = SecurityService();

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _hideSensitiveContent = false;

  RealtimeChannel? _channel;

  String? _matchId;
  String? _myUserId;
  String? _otherUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        if (mounted) {
          setState(() => _hideSensitiveContent = true);
        }
      }

      if (state == AppLifecycleState.resumed) {
        if (mounted) {
          setState(() => _hideSensitiveContent = false);
        }
      }
    }
  }

  Future<void> _initChat() async {
    try {
      _myUserId = supabase.auth.currentUser?.id;
      _otherUserId = widget.conversation.otherUserId;
      _matchId = widget.conversation.id;

      if (_myUserId == null || _otherUserId == null || _matchId == null) {
        setState(() => _loading = false);
        return;
      }

      await _loadMessages();
      _subscribeMessages();
      await _markMessagesAsRead();
    } catch (e) {
      _snack("Erreur chargement chat : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_matchId == null) return;

    final data = await supabase
        .from('messages')
        .select()
        .eq('match_id', _matchId!)
        .order('created_at', ascending: true);

    _messages = List<Map<String, dynamic>>.from(data);

    if (mounted) setState(() {});
    _scrollToBottom(jump: true);
  }

  void _subscribeMessages() {
    if (_matchId == null) return;

    _channel = supabase
        .channel('chat-$_matchId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'match_id',
        value: _matchId!,
      ),
      callback: (payload) async {
        final newRow = Map<String, dynamic>.from(payload.newRecord);

        final exists = _messages.any(
              (m) => m['id'].toString() == newRow['id'].toString(),
        );

        if (!exists) {
          setState(() {
            _messages.add(newRow);
          });
          _scrollToBottom();
        }

        await _markMessagesAsRead();
      },
    )
        .subscribe();
  }

  Future<void> _markMessagesAsRead() async {
    if (_matchId == null || _myUserId == null) return;

    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('match_id', _matchId!)
          .neq('author_id', _myUserId!)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _matchId == null || _myUserId == null) return;

    try {
      setState(() => _sending = true);

      await supabase.from('messages').insert({
        'match_id': _matchId,
        'author_id': _myUserId,
        'content': text,
        'is_read': false,
      });

      await supabase.from('matches').update({
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', _matchId!);

      _messageCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      _snack("Erreur envoi message : $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showUserActions() {
    if (_otherUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text(
                    'Bloquer cet utilisateur',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await security.blockUser(_otherUserId!);
                    if (!mounted) return;
                    _snack("Utilisateur bloqué");
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text(
                    'Signaler cet utilisateur',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showReportDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportDialog() async {
    if (_otherUserId == null) return;

    String selectedReason = 'arnaque';
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                "Signaler cet utilisateur",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: InputDecoration(
                      labelText: "Motif",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'faux_profil',
                        child: Text('Faux profil'),
                      ),
                      DropdownMenuItem(
                        value: 'arnaque',
                        child: Text('Arnaque'),
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
                        value: 'demande_argent',
                        child: Text('Demande d’argent'),
                      ),
                      DropdownMenuItem(
                        value: 'autre',
                        child: Text('Autre'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedReason = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Détails (optionnel)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Envoyer"),
                ),
              ],
            );
          },
        );
      },
    ) ??
        false;

    if (!confirmed) return;

    await security.reportUser(
      reportedUserId: _otherUserId!,
      reason: selectedReason,
      details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
    );

    if (!mounted) return;
    _snack("Signalement envoyé");
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;

      final target = _scrollCtrl.position.maxScrollExtent + 80;

      if (jump) {
        _scrollCtrl.jumpTo(target);
      } else {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildAvatar() {
    final avatar = widget.conversation.avatarUrl;

    if (avatar != null && avatar.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFFFE5E8),
        backgroundImage: NetworkImage(avatar),
      );
    }

    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFFFE5E8),
      child: Icon(Icons.person, color: Colors.black87),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();

    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F5FF);
    const bubbleMe = Color(0xFF111111);
    const bubbleOther = Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 110,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Image.asset(
              'assets/images/fasomatch_logo.png',
              width: 75,
              height: 75,
              errorBuilder: (_, __, ___) => const SizedBox(height: 8),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.conversation.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: _showUserActions,
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                  child: Text(
                    "Commencez la conversation ✨",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                )
                    : ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                  const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['author_id'] == _myUserId;
                    final content =
                    (msg['content'] ?? '').toString();
                    final time = _formatTime(msg['created_at']);

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                          MediaQuery.of(context).size.width *
                              0.74,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? bubbleMe : bubbleOther,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                            Radius.circular(isMe ? 18 : 6),
                            bottomRight:
                            Radius.circular(isMe ? 6 : 18),
                          ),
                          border: isMe
                              ? null
                              : Border.all(color: Colors.black12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            Text(
                              content,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    border: const Border(
                      top: BorderSide(color: Colors.black12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: TextField(
                            controller: _messageCtrl,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization:
                            TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: "Écrire un message...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _sending ? null : _sendMessage,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: bubbleMe,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: _sending
                              ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_hideSensitiveContent)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/fasomatch_logo.png',
                    width: 70,
                    height: 70,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Contenu protégé',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}