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
  final DateTime? lastSeenAt;
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
    required this.lastSeenAt,
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