import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../utils/constants.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _chats =>
      _db.collection(FirestoreCollections.chats);

  /// Real-time stream of all chats the current user is part of.
  Stream<List<ChatModel>> chatListStream() {
    return _chats
        .where('participants', arrayContains: _uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatModel.fromDoc(d)).toList());
  }

  /// Finds or creates a 1:1 chat between the current user and [otherUid].
  Future<String> getOrCreateDirectChat(String otherUid) async {
    final existing = await _chats
        .where('type', isEqualTo: ChatType.direct)
        .where('participants', arrayContains: _uid)
        .get();

    for (final doc in existing.docs) {
      final participants = List<String>.from(
          (doc.data() as Map<String, dynamic>)['participants'] ?? []);
      if (participants.contains(otherUid) && participants.length == 2) {
        return doc.id;
      }
    }

    final newChat = await _chats.add({
      'type': ChatType.direct,
      'participants': [_uid, otherUid],
      'admins': [],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': null,
      'pinnedBy': [],
      'favoritedBy': [],
      'archivedBy': [],
      'unreadBy': {},
      'typing': {},
    });
    return newChat.id;
  }

  Future<void> setTyping(String chatId, bool isTyping) {
    return _chats.doc(chatId).update({'typing.$_uid': isTyping});
  }

  Future<void> togglePinChat(String chatId, bool pinned) {
    return _chats.doc(chatId).update({
      'pinnedBy': pinned
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid])
    });
  }

  Future<void> toggleFavoriteChat(String chatId, bool favorite) {
    return _chats.doc(chatId).update({
      'favoritedBy': favorite
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid])
    });
  }

  Future<void> toggleArchiveChat(String chatId, bool archived) {
    return _chats.doc(chatId).update({
      'archivedBy': archived
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid])
    });
  }

  Future<void> markUnread(String chatId, bool unread) {
    return _chats.doc(chatId).update({
      'unreadBy.$_uid': unread ? 1 : 0,
    });
  }

  Future<void> resetUnreadCount(String chatId) {
    return _chats.doc(chatId).update({'unreadBy.$_uid': 0});
  }

  Future<void> incrementUnreadForOthers(
      String chatId, List<String> participants) async {
    final updates = <String, dynamic>{};
    for (final uid in participants) {
      if (uid == _uid) continue;
      updates['unreadBy.$uid'] = FieldValue.increment(1);
    }
    if (updates.isNotEmpty) {
      await _chats.doc(chatId).update(updates);
    }
  }

  /// Clears chat history for the current user only (messages remain for
  /// other participants; this simply hides them locally by tagging
  /// deletedFor on each message the user can see).
  Future<void> clearHistoryForMe(String chatId) async {
    final msgs = await _chats.doc(chatId).collection(FirestoreCollections.messages).get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([_uid])
      });
    }
    await batch.commit();
  }

  /// Deletes the conversation for the current user (removes them from
  /// participants; group chat data persists for remaining members).
  Future<void> deleteConversation(String chatId, bool isGroup) async {
    if (isGroup) {
      await _chats.doc(chatId).update({
        'participants': FieldValue.arrayRemove([_uid]),
        'admins': FieldValue.arrayRemove([_uid]),
      });
    } else {
      await clearHistoryForMe(chatId);
      await _chats.doc(chatId).update({
        'archivedBy': FieldValue.arrayUnion([_uid])
      });
    }
  }
}
