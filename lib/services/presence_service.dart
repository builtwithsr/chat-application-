import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../utils/constants.dart';

/// Tracks the current user's online/offline status by hooking into the
/// app lifecycle. Call [attach] once after login (e.g. from a top-level
/// widget's initState) and [detach] on dispose/logout.
class PresenceService with WidgetsBindingObserver {
  final _db = FirebaseFirestore.instance;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _setStatus('online');
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    _setStatus('offline');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setStatus('online');
    } else {
      _setStatus('offline');
    }
  }

  void _setStatus(String status) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _db.collection(FirestoreCollections.users).doc(uid).update({
      'status': status,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
