import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String content;
  final String authorUid;
  final String authorNickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CommentModel({
    required this.id,
    required this.content,
    required this.authorUid,
    required this.authorNickname,
    this.createdAt,
    this.updatedAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CommentModel(
      id: doc.id,
      content: data['content'] ?? '',
      authorUid: data['authorUid'] ?? '',
      authorNickname: data['authorNickname'] ?? '익명',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
