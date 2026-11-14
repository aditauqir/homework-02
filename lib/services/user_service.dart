import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

/// Centralizes all user profile operations in Cloud Firestore.
///
/// Encapsulates operations on the private `users/{uid}` documents.
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Saves the user record upon registration with the 5 required fields.
  ///
  /// Required fields: `uid`, `firstName`, `lastName`, `role`, and `registrationDateTime`.
  Future<void> saveUserRecord(
    User user, {
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final docRef = _db.collection('users').doc(user.uid);
    await docRef.set({
      'uid': user.uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'role': role.trim(),
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches the user profile document from `users/{uid}`.
  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return UserProfile.fromFirestore(snapshot);
  }

  /// Checks if the user record exists and has all 5 required fields.
  Future<bool> hasValidRecord(String uid) async {
    try {
      final profile = await getUserProfile(uid);
      return profile != null && profile.isComplete;
    } catch (_) {
      return false;
    }
  }

  /// Connects Firestore to the local emulator for testing (Spice #1).
  void useEmulator({
    String host = '10.0.2.2',
    int port = 8080,
  }) {
    _db.useFirestoreEmulator(host, port);
  }
}
