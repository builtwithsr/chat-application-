import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String status; // "online" | "offline"
  final Timestamp? lastSeen;
  final bool showLastSeen;
  final bool showOnlineStatus;
  final bool showReadReceipts;
  final List<String> blockedUsers;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.status = 'offline',
    this.lastSeen,
    this.showLastSeen = true,
    this.showOnlineStatus = true,
    this.showReadReceipts = true,
    this.blockedUsers = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'offline',
      lastSeen: map['lastSeen'],
      showLastSeen: map['showLastSeen'] ?? true,
      showOnlineStatus: map['showOnlineStatus'] ?? true,
      showReadReceipts: map['showReadReceipts'] ?? true,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'status': status,
      'lastSeen': lastSeen,
      'showLastSeen': showLastSeen,
      'showOnlineStatus': showOnlineStatus,
      'showReadReceipts': showReadReceipts,
      'blockedUsers': blockedUsers,
    };
  }

  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}
