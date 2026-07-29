import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';
import 'chat_service.dart';

class MessageService {
  final _db = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference _messagesRef(String chatId) => _db
      .collection(FirestoreCollections.chats)
      .doc(chatId)
      .collection(FirestoreCollections.messages);

  /// Real-time stream of the most recent [limit] messages.
  Stream<List<MessageModel>> messagesStream(String chatId, {int limit = messagePageSize}) {
    return _messagesRef(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  /// Pagination: fetch older messages before [lastDoc] for infinite scroll.
  Future<List<MessageModel>> fetchOlderMessages(
    String chatId,
    DocumentSnapshot lastDoc, {
    int limit = messagePageSize,
  }) async {
    final snap = await _messagesRef(chatId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();
    return snap.docs.map((d) => MessageModel.fromDoc(d)).toList();
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    required List<String> participants,
  }) async {
    // Check if any participant has blocked the sender
    if (participants.length == 2) {
      final otherUid = participants.firstWhere((p) => p != _uid);
      final otherDoc = await _db.collection(FirestoreCollections.users).doc(otherUid).get();
      final blockedList = List<String>.from(otherDoc.data()?['blockedUsers'] ?? []);
      if (blockedList.contains(_uid)) {
        throw Exception('You are blocked by this user');
      }
    }

    final doc = await _messagesRef(chatId).add({
      'senderId': _uid,
      'text': text,
      'type': MessageType.text,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'deletedFor': <String>[],
      'deletedForEveryone': false,
      'status': MessageStatus.sent,
      'readBy': <String>[],
      'deliveredTo': <String>[],
      'reactions': <String, dynamic>{},
      'pinned': false,
      'starredBy': <String>[],
    });
    await _touchChat(chatId, text, participants, doc.id);
  }

  Future<void> sendPollMessage({
    required String chatId,
    required String question,
    required List<String> options,
    required bool allowMultiple,
    required List<String> participants,
  }) async {
    final doc = await _messagesRef(chatId).add({
      'senderId': _uid,
      'text': question,
      'type': MessageType.poll,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': <String>[],
      'deletedForEveryone': false,
      'status': MessageStatus.sent,
      'readBy': <String>[],
      'deliveredTo': <String>[],
      'reactions': <String, dynamic>{},
      'pinned': false,
      'starredBy': <String>[],
      'poll': {
        'question': question,
        'allowMultiple': allowMultiple,
        'options': options.map((o) => {'text': o, 'votes': <String>[]}).toList(),
      },
    });
    await _touchChat(chatId, '📊 Poll: $question', participants, doc.id);
  }

  Future<void> voteOnPoll({
    required String chatId,
    required String messageId,
    required int optionIndex,
    required bool allowMultiple,
  }) async {
    final ref = _messagesRef(chatId).doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;
      final poll = Map<String, dynamic>.from(data['poll']);
      final options = List<Map<String, dynamic>>.from(poll['options']);

      for (var i = 0; i < options.length; i++) {
        final votes = List<String>.from(options[i]['votes'] ?? []);
        final alreadyVoted = votes.contains(_uid);
        if (i == optionIndex) {
          if (alreadyVoted) {
            votes.remove(_uid); // toggle off
          } else {
            votes.add(_uid);
          }
        } else if (!allowMultiple && votes.contains(_uid)) {
          votes.remove(_uid); // single-choice: clear other options
        }
        options[i]['votes'] = votes;
      }
      poll['options'] = options;
      tx.update(ref, {'poll': poll});
    });
  }

  Future<void> sendLocationMessage({
    required String chatId,
    required double lat,
    required double lng,
    required List<String> participants,
  }) async {
    final doc = await _messagesRef(chatId).add({
      'senderId': _uid,
      'text': 'Location',
      'type': MessageType.location,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': <String>[],
      'deletedForEveryone': false,
      'status': MessageStatus.sent,
      'readBy': <String>[],
      'deliveredTo': <String>[],
      'reactions': <String, dynamic>{},
      'pinned': false,
      'starredBy': <String>[],
      'location': {'lat': lat, 'lng': lng},
    });
    await _touchChat(chatId, '📍 Location', participants, doc.id);
  }

  Future<void> _touchChat(
      String chatId, String preview, List<String> participants, String lastMsgId) async {
    await _db.collection(FirestoreCollections.chats).doc(chatId).update({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _uid,
      'lastMessageId': lastMsgId,
    });
    await _chatService.incrementUnreadForOthers(chatId, participants);
  }

  Future<void> editMessage(String chatId, String messageId, String newText) {
    return _messagesRef(chatId).doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete for me only.
  Future<void> deleteForMe(String chatId, String messageId) {
    return _messagesRef(chatId).doc(messageId).update({
      'deletedFor': FieldValue.arrayUnion([_uid])
    });
  }

  /// Delete for everyone (only allowed for the sender — enforce in UI/rules).
  Future<void> deleteForEveryone(String chatId, String messageId) {
    return _messagesRef(chatId).doc(messageId).update({
      'deletedForEveryone': true,
      'text': '',
    });
  }

  Future<void> forwardMessage({
    required String targetChatId,
    required MessageModel message,
    required List<String> participants,
  }) async {
    await sendTextMessage(
      chatId: targetChatId,
      text: message.text,
      participants: participants,
    );
  }

  Future<void> togglePinMessage(String chatId, String messageId, bool pinned) {
    return _messagesRef(chatId).doc(messageId).update({'pinned': pinned});
  }

  Future<void> toggleStarMessage(String chatId, String messageId, bool starred) {
    return _messagesRef(chatId).doc(messageId).update({
      'starredBy': starred
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid])
    });
  }

  /// Sets/changes/removes the current user's reaction on a message.
  Future<void> setReaction(String chatId, String messageId, String? emoji) {
    if (emoji == null) {
      return _messagesRef(chatId).doc(messageId).update({
        'reactions.$_uid': FieldValue.delete(),
      });
    }
    return _messagesRef(chatId).doc(messageId).update({
      'reactions.$_uid': emoji,
    });
  }

  Future<void> markDelivered(String chatId, String messageId) {
    return _messagesRef(chatId).doc(messageId).update({
      'deliveredTo': FieldValue.arrayUnion([_uid]),
      'status': MessageStatus.delivered,
    });
  }

  Future<void> markRead(String chatId, String messageId) async {
    // Check if user has read receipts enabled before marking as read
    final uid = _uid;
    final userDoc = await _db.collection(FirestoreCollections.users).doc(uid).get();
    final showReadReceipts = userDoc.data()?['showReadReceipts'] ?? true;
    
    if (!showReadReceipts) return;

    return _messagesRef(chatId).doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid]),
      'status': MessageStatus.read,
    });
  }

  Future<void> markLastMessageAsDelivered(String chatId, String messageId) {
    return _messagesRef(chatId).doc(messageId).update({
      'deliveredTo': FieldValue.arrayUnion([_uid]),
      'status': MessageStatus.delivered,
    });
  }

  /// Marks messages as delivered for the current user.
  Future<void> markAllVisibleAsDelivered(String chatId, List<MessageModel> messages) async {
    final batch = _db.batch();
    bool changed = false;
    for (final m in messages) {
      if (m.senderId != _uid && !m.deliveredTo.contains(_uid)) {
        batch.update(_messagesRef(chatId).doc(m.id), {
          'deliveredTo': FieldValue.arrayUnion([_uid]),
          if (m.status == MessageStatus.sent) 'status': MessageStatus.delivered,
        });
        changed = true;
      }
    }
    if (changed) await batch.commit();
  }

  /// Marks all currently-loaded messages not sent by the user as read and delivered.
  Future<void> markAllVisibleAsRead(String chatId, List<MessageModel> messages) async {
    final batch = _db.batch();
    bool changed = false;
    for (final m in messages) {
      if (m.senderId != _uid) {
        final updates = <String, dynamic>{};
        if (!m.deliveredTo.contains(_uid)) {
          updates['deliveredTo'] = FieldValue.arrayUnion([_uid]);
        }
        if (!m.readBy.contains(_uid)) {
          updates['readBy'] = FieldValue.arrayUnion([_uid]);
          updates['status'] = MessageStatus.read;
        } else if (!m.deliveredTo.contains(_uid)) {
          // If already read but not marked delivered in the array (rare)
          if (m.status == MessageStatus.sent) updates['status'] = MessageStatus.delivered;
        }
        
        if (updates.isNotEmpty) {
          batch.update(_messagesRef(chatId).doc(m.id), updates);
          changed = true;
        }
      }
    }
    if (changed) {
      await batch.commit();
    }
    await _chatService.resetUnreadCount(chatId);
  }

  /// Simple client-side search across loaded messages in a chat
  /// (Firestore doesn't support full-text search natively).
  Future<List<MessageModel>> searchInChat(String chatId, String query) async {
    final snap = await _messagesRef(chatId).orderBy('createdAt', descending: true).get();
    final all = snap.docs.map((d) => MessageModel.fromDoc(d)).toList();
    return all
        .where((m) =>
            !m.isDeletedFor(_uid) &&
            m.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Stream<List<MessageModel>> pinnedMessagesStream(String chatId) {
    return _messagesRef(chatId)
        .where('pinned', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  Stream<List<MessageModel>> starredMessagesStream(String chatId) {
    return _messagesRef(chatId)
        .where('starredBy', arrayContains: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }
}
