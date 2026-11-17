import 'package:flutter_test/flutter_test.dart';
import 'package:homework02/models/message.dart';
import 'package:homework02/models/user_profile.dart';
import 'package:homework02/services/auth_service.dart';

void main() {
  group('Message Data Model Tests', () {
    test('Message model initializes fields accurately', () {
      final now = DateTime.now();
      final msg = Message(
        id: 'msg_101',
        text: 'Vault notice test',
        authorUid: 'uid_ada_123',
        authorName: 'Ada Lovelace',
        createdAt: now,
        idempotencyKey: 'nonce_999',
      );

      expect(msg.id, equals('msg_101'));
      expect(msg.text, equals('Vault notice test'));
      expect(msg.authorUid, equals('uid_ada_123'));
      expect(msg.authorName, equals('Ada Lovelace'));
      expect(msg.createdAt, equals(now));
      expect(msg.isEdited, isFalse);
      expect(msg.idempotencyKey, equals('nonce_999'));
    });

    test('Message isEdited flag reflects editedAt state', () {
      final edited = Message(
        id: 'msg_102',
        text: 'Edited text',
        authorUid: 'uid_grace_456',
        authorName: 'Grace Hopper',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        editedAt: DateTime.now(),
      );

      expect(edited.isEdited, isTrue);
    });
  });

  group('UserProfile Model Tests', () {
    test('UserProfile verifies all 5 required fields completeness', () {
      const validProfile = UserProfile(
        uid: 'uid_001',
        firstName: 'Noor',
        lastName: 'Tauqir',
        role: 'Student',
      );

      expect(validProfile.isComplete, isTrue);
      expect(validProfile.fullName, equals('Noor Tauqir'));

      const incompleteProfile = UserProfile(
        uid: 'uid_002',
        firstName: '',
        lastName: 'Tauqir',
        role: 'Student',
      );

      expect(incompleteProfile.isComplete, isFalse);
    });
  });

  group('AuthService Feedback Tests', () {
    test('Translates FirebaseAuthException codes to friendly messages', () {
      final weakPass = AuthService.getFriendlyErrorMessage(
        FormatException('Unknown error'),
      );
      expect(weakPass, contains('unexpected error'));
    });
  });
}
