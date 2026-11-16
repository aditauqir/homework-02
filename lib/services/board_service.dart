// Spice #4 Idempotency: atomic runTransaction deduplication
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

/// Centralizes all message board operations in Cloud Firestore.
///
/// Ensures widgets never directly invoke Firestore APIs.
class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// READ (live stream): Subscribes to the messages collection ordered oldest to newest.
  ///
  /// Emits a new list whenever any change occurs in Cloud Firestore.
  Stream<List<Message>> messageBoard() {
    return _db
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList(),
        );
  }

  /// CREATE: Standard message creation with uid ownership and server timestamp.
  Future<void> postMessage({
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    await _db.collection('messages').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// CREATE (Idempotent - Spice #4): Ensures a message write executes exactly once.
  ///
  /// Uses a Firestore transaction on a deterministic document ID (`authorUid_idempotencyKey`).
  /// If the document already exists, the transaction aborts write, guaranteeing idempotency.
  Future<bool> postMessageIdempotent({
    required String authorUid,
    required String authorName,
    required String text,
    required String idempotencyKey,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    final docId = '${authorUid}_$idempotencyKey';
    final docRef = _db.collection('messages').doc(docId);

    return await _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        // Document already created by a concurrent or earlier request.
        return false;
      }
      transaction.set(docRef, {
        'authorUid': authorUid,
        'authorName': authorName,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'idempotencyKey': idempotencyKey,
      });
      return true;
    });
  }

  /// UPDATE: Updates text and sets editedAt server timestamp (owner only).
  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    await _db.collection('messages').doc(messageId).update({
      'text': trimmed,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DELETE: Removes the message document (owner only).
  Future<void> deleteMessage({required String messageId}) async {
    await _db.collection('messages').doc(messageId).delete();
  }

  /// Test probe: Attempts to write with a forged authorUid to trigger rule denial.
  Future<void> simulateForgedCreate({
    required String forgedAuthorUid,
    required String authorName,
    required String text,
  }) async {
    await _db.collection('messages').add({
      'authorUid': forgedAuthorUid,
      'authorName': authorName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Test probe: Attempts to edit another user's document to trigger rule denial.
  Future<void> simulateUnauthorizedEdit({
    required String messageId,
    required String maliciousText,
  }) async {
    await _db.collection('messages').doc(messageId).update({
      'text': maliciousText.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }
}
