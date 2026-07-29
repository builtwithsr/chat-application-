import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  AppUser? _profile;
  bool _loading = false;
  String? _error;

  AppUser? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  User? get firebaseUser => _authService.currentUser;
  bool get isLoggedIn => _authService.currentUser != null;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<void> loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    
    // Attach presence when loading profile
    _presenceService.attach();
    
    final doc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    if (doc.exists) {
      _profile = AppUser.fromMap(uid, doc.data()!);
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String displayName) async {
    _setLoading(true);
    try {
      await _authService.register(
          email: email, password: password, displayName: displayName);
      // Background this so it doesn't block the UI transition
      loadProfile().catchError((e) => print("Profile load error: $e"));
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.login(email: email, password: password);
      // Background this so it doesn't block the UI transition
      loadProfile().catchError((e) => print("Profile load error: $e"));
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _authService.updateDisplayName(name);
    await loadProfile();
  }

  Future<void> updatePrivacy(String field, bool value) async {
    await _authService.updatePrivacySetting(field, value);
    await loadProfile();
  }

  Future<void> toggleBlock(String otherUid, bool block) async {
    await _authService.toggleBlockUser(otherUid, block);
    await loadProfile();
  }

  Future<void> logout() async {
    await _authService.logout();
    _profile = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    _error = null;
    notifyListeners();
  }
}
