import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String text;
  final List<String> votes;
  PollOption({required this.text, this.votes = const []});

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
        text: map['text'] ?? '',
        votes: List<String>.from(map['votes'] ?? []),
      );

  Map<String, dynamic> toMap() => {'text': text, 'votes': votes};
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // "text" | "poll" | "location"
  final Timestamp? createdAt;
  final Timestamp? editedAt;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final String status; // "sent" | "delivered" | "read"
  final List<String> readBy;
  final List<String> deliveredTo;
  final Map<String, dynamic> reactions; // uid -> emoji
  final bool pinned;
  final List<String> starredBy;
  final String? pollQuestion;
  final List<PollOption> pollOptions;
  final bool pollAllowMultiple;
  final double? locationLat;
  final double? locationLng;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.createdAt,
    this.editedAt,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.status = 'sent',
    this.readBy = const [],
    this.deliveredTo = const [],
    this.reactions = const {},
    this.pinned = false,
    this.starredBy = const [],
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollAllowMultiple = false,
    this.locationLat,
    this.locationLng,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final poll = map['poll'] as Map<String, dynamic>?;
    final location = map['location'] as Map<String, dynamic>?;
    return MessageModel(
      id: doc.id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      createdAt: map['createdAt'],
      editedAt: map['editedAt'],
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      deletedForEveryone: map['deletedForEveryone'] ?? false,
      status: map['status'] ?? 'sent',
      readBy: List<String>.from(map['readBy'] ?? []),
      deliveredTo: List<String>.from(map['deliveredTo'] ?? []),
      reactions: Map<String, dynamic>.from(map['reactions'] ?? {}),
      pinned: map['pinned'] ?? false,
      starredBy: List<String>.from(map['starredBy'] ?? []),
      pollQuestion: poll?['question'],
      pollOptions: poll == null
          ? []
          : List<Map<String, dynamic>>.from(poll['options'] ?? [])
              .map((o) => PollOption.fromMap(o))
              .toList(),
      pollAllowMultiple: poll?['allowMultiple'] ?? false,
      locationLat: (location?['lat'] as num?)?.toDouble(),
      locationLng: (location?['lng'] as num?)?.toDouble(),
    );
  }

  bool isDeletedFor(String uid) =>
      deletedForEveryone || deletedFor.contains(uid);
}
