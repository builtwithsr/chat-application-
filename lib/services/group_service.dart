import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _chats =>
      _db.collection(FirestoreCollections.chats);

  Future<String> createGroup({
    required String groupName,
    required List<String> memberUids,
  }) async {
    final participants = {...memberUids, _uid}.toList();
    final doc = await _chats.add({
      'type': ChatType.group,
      'participants': participants,
      'admins': [_uid],
      'groupName': groupName,
      'groupCreatedBy': _uid,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': null,
      'pinnedBy': [],
      'favoritedBy': [],
      'archivedBy': [],
      'unreadBy': {},
      'typing': {},
    });
    return doc.id;
  }

  Future<void> renameGroup(String chatId, String newName) {
    return _chats.doc(chatId).update({'groupName': newName});
  }

  Future<void> addMembers(String chatId, List<String> uids) {
    return _chats.doc(chatId).update({
      'participants': FieldValue.arrayUnion(uids),
    });
  }

  Future<void> removeMember(String chatId, String uid) {
    return _chats.doc(chatId).update({
      'participants': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> makeAdmin(String chatId, String uid) {
    return _chats.doc(chatId).update({
      'admins': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeAdmin(String chatId, String uid) {
    return _chats.doc(chatId).update({
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> leaveGroup(String chatId) {
    return _chats.doc(chatId).update({
      'participants': FieldValue.arrayRemove([_uid]),
      'admins': FieldValue.arrayRemove([_uid]),
    });
  }
}
