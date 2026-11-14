import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a private user document in `users/{uid}`.
///
/// Contains the 5 required fields mandated by the homework spec:
/// `uid`, `firstName`, `lastName`, `role`, and `registrationDateTime`.
class UserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime? registrationDateTime;

  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.registrationDateTime,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('User document does not exist.');
    }

    DateTime? regTime;
    final rawTime = data['registrationDateTime'];
    if (rawTime is Timestamp) {
      regTime = rawTime.toDate();
    } else if (rawTime is String) {
      regTime = DateTime.tryParse(rawTime);
    }

    return UserProfile(
      uid: data['uid'] as String? ?? snapshot.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      role: data['role'] as String? ?? 'Student',
      registrationDateTime: regTime,
    );
  }

  /// Verifies all 5 required fields exist and are non-empty.
  bool get isComplete {
    return uid.isNotEmpty &&
        firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        role.isNotEmpty;
  }
}
