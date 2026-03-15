import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../moderation/user_moderation_sheet.dart';
import 'conversation_preview.dart';

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

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _hideSensitiveContent = false;

  bool _isOtherOnline = false;
  DateTime? _otherLastSeenAt;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _profileChannel;

  String? _matchId;
  String? _myUserId;
  String? _otherUserId;

  bool _chatBlocked = false;
  String _blockedReason =
      "Cette conversation n’est plus disponible pour le moment.";

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

  String _normalizePhone(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _profileVisible(Map<String, dynamic> row) {
    final isActive = (row['is_active'] as bool?) ?? true;
    final status = (row['account_status'] ?? '').toString().toLowerCase();

    if (!isActive) return false;
    if (status == 'inactive' ||
        status == 'disabled' ||
        status == 'deactivated' ||
        status == 'hidden') {
      return false;
    }

    return true;
  }

  Future<bool> _isBlockedOrUnavailable() async {
    final me = _myUserId;
    final other = _otherUserId;
    if (me == null || other == null) return true;

    try {
      final myProfileRaw = await supabase
          .from('profiles')
          .select('id, phone, is_active, account_status')
          .eq('id', me)
          .maybeSingle();

      final otherProfileRaw = await supabase
          .from('profiles')
          .select('id, phone, is_active, account_status')
          .eq('id', other)
          .maybeSingle();

      if (myProfileRaw == null || otherProfileRaw == null) {
        _blockedReason = "Ce profil n’est plus disponible.";
        return true;
      }

      final myProfile = Map<String, dynamic>.from(myProfileRaw as Map);
      final otherProfile = Map<String, dynamic>.from(otherProfileRaw as Map);

      if (!_profileVisible(otherProfile)) {
        _blockedReason = "Ce profil a été masqué ou désactivé.";
        return true;
      }

      final classicBlockedByMe = await supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', me)
          .eq('blocked_id', other)
          .limit(1);

      if ((classicBlockedByMe as List).isNotEmpty) {
        _blockedReason = "Tu as bloqué cet utilisateur.";
        return true;
      }

      final classicBlockedMe = await supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', other)
          .eq('blocked_id', me)
          .limit(1);

      if ((classicBlockedMe as List).isNotEmpty) {
        _blockedReason = "Cet utilisateur n’est plus disponible.";
        return true;
      }

      final myPhone = _normalizePhone(myProfile['phone']?.toString());
      final otherPhone = _normalizePhone(otherProfile['phone']?.toString());

      if (otherPhone.isNotEmpty) {
        final discreetByMe = await supabase
            .from('discreet_blocks')
            .select('id')
            .eq('owner_user_id', me)
            .eq('blocked_phone_e164', otherPhone)
            .limit(1);

        if ((discreetByMe as List).isNotEmpty) {
          _blockedReason = "Tu as masqué ce contact.";
          return true;
        }
      }

      if (myPhone.isNotEmpty) {
        final discreetMe = await supabase
            .from('discreet_blocks')
            .select('id')
            .eq('owner_user_id', other)
            .eq('blocked_phone_e164', myPhone)
            .limit(1);

        if ((discreetMe as List).isNotEmpty) {
          _blockedReason = "Cet utilisateur n’est plus disponible.";
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('_isBlockedOrUnavailable error: $e');
      _blockedReason = "Impossible de vérifier l’accès à ce chat.";
      return true;
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

      final blocked = await _isBlockedOrUnavailable();
      if (blocked) {
        if (!mounted) return;
        setState(() {
          _chatBlocked = true;
          _loading = false;
        });
        return;
      }

      await _loadMessages();
      await _loadOtherUserPresence();
      _subscribeMessages();
      _subscribePresence();
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

  Future<void> _loadOtherUserPresence() async {
    if (_otherUserId == null) return;

    final row = await supabase
        .from('profiles')
        .select('is_online, last_seen_at')
        .eq('id', _otherUserId!)
        .maybeSingle();

    if (row == null || !mounted) return;

    setState(() {
      _isOtherOnline = (row['is_online'] as bool?) ?? false;
      _otherLastSeenAt = row['last_seen_at'] != null
          ? DateTime.tryParse(row['last_seen_at'].toString())
          : null;
    });
  }

  void _subscribeMessages() {
    if (_matchId == null) return;

    _messageChannel = supabase
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

  void _subscribePresence() {
    if (_otherUserId == null) return;

    _profileChannel = supabase
        .channel('profile-presence-$_otherUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: _otherUserId!,
      ),
      callback: (payload) async {
        final row = Map<String, dynamic>.from(payload.newRecord);
        if (!mounted) return;

        setState(() {
          _isOtherOnline = (row['is_online'] as bool?) ?? false;
          _otherLastSeenAt = row['last_seen_at'] != null
              ? DateTime.tryParse(row['last_seen_at'].toString())
              : null;
        });

        final blocked = await _isBlockedOrUnavailable();
        if (!mounted) return;
        if (blocked) {
          setState(() {
            _chatBlocked = true;
          });
        }
      },
    )
        .subscribe();
  }

  Future<void> _markMessagesAsRead() async {
    if (_matchId == null || _myUserId == null || _chatBlocked) return;

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
    if (_chatBlocked) {
      _snack(_blockedReason);
      return;
    }

    final blockedNow = await _isBlockedOrUnavailable();
    if (blockedNow) {
      if (!mounted) return;
      setState(() => _chatBlocked = true);
      _snack(_blockedReason);
      return;
    }

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

  Future<void> _openModerationSheet() async {
    if (_otherUserId == null) return;

    await showUserModerationSheet(
      context: context,
      reportedUserId: _otherUserId!,
      displayedName: widget.conversation.name,
    );

    if (!mounted) return;

    final blocked = await _isBlockedOrUnavailable();
    if (blocked) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {});
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

  String _presenceLabel() {
    if (_chatBlocked) return 'Indisponible';
    if (_isOtherOnline) return 'En ligne';
    if (_otherLastSeenAt == null) return 'Hors ligne';

    final dt = _otherLastSeenAt!.toLocal();
    return 'Vu à ${DateFormat('HH:mm').format(dt)}';
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

    if (_messageChannel != null) {
      supabase.removeChannel(_messageChannel!);
    }
    if (_profileChannel != null) {
      supabase.removeChannel(_profileChannel!);
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
        toolbarHeight: 116,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context, _chatBlocked),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildAvatar(),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _chatBlocked
                              ? Colors.grey.shade400
                              : _isOtherOnline
                              ? const Color(0xFF22C55E)
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.conversation.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _presenceLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: _chatBlocked
                              ? Colors.black45
                              : _isOtherOnline
                              ? const Color(0xFF22C55E)
                              : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: _openModerationSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              if (_chatBlocked)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.28),
                    ),
                  ),
                  child: Text(
                    _blockedReason,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                  child: Text(
                    _chatBlocked
                        ? "Conversation indisponible"
                        : "Commencez la conversation ✨",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                )
                    : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['author_id'] == _myUserId;
                    final content = (msg['content'] ?? '').toString();
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
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                            enabled: !_chatBlocked,
                            textCapitalization:
                            TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _chatBlocked
                                  ? "Conversation indisponible"
                                  : "Écrire un message...",
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
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
                        onTap:
                        (_sending || _chatBlocked) ? null : _sendMessage,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _chatBlocked
                                ? Colors.grey.shade400
                                : bubbleMe,
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