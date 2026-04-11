import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';

/// User profile data
class UserProfile {
  final String userId;
  final String email;
  final String? displayName;
  final int totalContentViewed;
  final int totalMinutesWatched;
  final bool skipSessionSelection;

  UserProfile({
    required this.userId,
    required this.email,
    this.displayName,
    this.totalContentViewed = 0,
    this.totalMinutesWatched = 0,
    this.skipSessionSelection = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      totalContentViewed: map['totalContentViewed'] ?? 0,
      totalMinutesWatched: map['totalMinutesWatched'] ?? 0,
      skipSessionSelection: map['skipSessionSelection'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'totalContentViewed': totalContentViewed,
      'totalMinutesWatched': totalMinutesWatched,
      'skipSessionSelection': skipSessionSelection,
    };
  }
}

/// Firestore Service - handles all database operations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── User Profile ──────────────────────────────────────

  Future<void> createUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists) return;

    await docRef.set({
      'userId': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'totalContentViewed': 0,
      'totalMinutesWatched': 0,
      'skipSessionSelection': false,
    });
  }

  Future<void> updateLastLogin(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore - not critical
    }
  }

  Stream<UserProfile?> watchUserProfile(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  Future<void> updateSkipSessionSelection(String userId, bool skip) async {
    await _db.collection('users').doc(userId).update({
      'skipSessionSelection': skip,
    });
  }

  Future<void> incrementContentViewed(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'totalContentViewed': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> addMinutesWatched(String userId, int minutes) async {
    try {
      await _db.collection('users').doc(userId).update({
        'totalMinutesWatched': FieldValue.increment(minutes),
      });
    } catch (_) {}
  }

  // ─── User Preferences ─────────────────────────────────

  Future<void> saveUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    await _db
        .collection('user_preferences')
        .doc(userId)
        .set(preferences.toMap(), SetOptions(merge: true));
  }

  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      final doc =
          await _db.collection('user_preferences').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserPreferences.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<UserPreferences?> watchUserPreferences(String userId) {
    return _db
        .collection('user_preferences')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserPreferences.fromMap(doc.data()!);
    });
  }

  // ─── Bookmarks / Saved Items ───────────────────────────

  Future<void> saveItem(String userId, Map<String, dynamic> item) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(item['id'])
        .set({...item, 'savedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unsaveItem(String userId, String itemId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(itemId)
        .delete();
  }

  Future<bool> isItemSaved(String userId, String itemId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('saved')
          .doc(itemId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchSavedItems(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
