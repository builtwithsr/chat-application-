import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);

    // Don't 'await' the Firestore set -- let it happen in background
    // so the auth flow can complete immediately.
    _db.collection(FirestoreCollections.users).doc(cred.user!.uid).set({
      'displayName': displayName,
      'email': email,
      'status': 'online',
      'lastSeen': FieldValue.serverTimestamp(),
      'showLastSeen': true,
      'showOnlineStatus': true,
      'showReadReceipts': true,
      'blockedUsers': <String>[],
    }).catchError((e) => print("Firestore register error: $e"));
  }

  Future<void> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Don't 'await' the update.
    _db.collection(FirestoreCollections.users).doc(cred.user!.uid).update({
      'status': 'online',
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((e) => print("Firestore login error: $e"));
  }

  Future<void> updateDisplayName(String newName) async {
    final uid = currentUser!.uid;
    await currentUser!.updateDisplayName(newName);
    _db.collection(FirestoreCollections.users).doc(uid).update({
      'displayName': newName,
    });
  }

  Future<void> updatePrivacySetting(String field, bool value) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      field: value,
    });
  }

  Future<void> toggleBlockUser(String otherUid, bool block) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'blockedUsers': block
          ? FieldValue.arrayUnion([otherUid])
          : FieldValue.arrayRemove([otherUid]),
    });
  }

  Future<void> logout() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await _db.collection(FirestoreCollections.users).doc(uid).update({
        'status': 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await _auth.signOut();
  }
}
