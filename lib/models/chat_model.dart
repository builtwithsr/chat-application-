import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String type; // "direct" | "group"
  final List<String> participants;
  final List<String> admins;
  final String? groupName;
  final String? groupCreatedBy;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessageId;
  final List<String> pinnedBy;
  final List<String> favoritedBy;
  final List<String> archivedBy;
  final Map<String, dynamic> unreadBy;
  final Map<String, dynamic> typing;

  ChatModel({
    required this.id,
    required this.type,
    required this.participants,
    this.admins = const [],
    this.groupName,
    this.groupCreatedBy,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageId,
    this.pinnedBy = const [],
    this.favoritedBy = const [],
    this.archivedBy = const [],
    this.unreadBy = const {},
    this.typing = const {},
  });

  bool get isGroup => type == 'group';

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      type: map['type'] ?? 'direct',
      participants: List<String>.from(map['participants'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      groupName: map['groupName'],
      groupCreatedBy: map['groupCreatedBy'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt: map['lastMessageAt'],
      lastMessageSenderId: map['lastMessageSenderId'],
      lastMessageId: map['lastMessageId'],
      pinnedBy: List<String>.from(map['pinnedBy'] ?? []),
      favoritedBy: List<String>.from(map['favoritedBy'] ?? []),
      archivedBy: List<String>.from(map['archivedBy'] ?? []),
      unreadBy: Map<String, dynamic>.from(map['unreadBy'] ?? {}),
      typing: Map<String, dynamic>.from(map['typing'] ?? {}),
    );
  }

  int unreadCountFor(String uid) => (unreadBy[uid] ?? 0) as int;
}
