import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a public board message stored in `messages/{msgId}`.
class Message {
  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final String? idempotencyKey;

  const Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
    this.idempotencyKey,
  });

  bool get isEdited => editedAt != null;

  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'text': text,
      'authorUid': authorUid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (idempotencyKey != null) {
      map['idempotencyKey'] = idempotencyKey;
    }
    return map;
  }

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Message document ${snapshot.id} does not exist.');
    }

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    }

    DateTime? edited;
    final rawEdited = data['editedAt'];
    if (rawEdited is Timestamp) {
      edited = rawEdited.toDate();
    }

    return Message(
      id: snapshot.id,
      text: data['text'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Anonymous',
      createdAt: created,
      editedAt: edited,
      idempotencyKey: data['idempotencyKey'] as String?,
    );
  }
}
