import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String authorUid;
  final String authorNickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> likedBy;
  final int commentCount;
  final bool deleted;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorUid,
    required this.authorNickname,
    this.createdAt,
    this.updatedAt,
    this.likedBy = const [],
    this.commentCount = 0,
    this.deleted = false,
  });

  int get likeCount => likedBy.length;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'likedBy': likedBy,
      'commentCount': commentCount,
      'deleted': deleted,
    };
  }

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorUid: map['authorUid'] ?? '',
      authorNickname: map['authorNickname'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentCount: map['commentCount'] as int? ?? 0,
      deleted: map['deleted'] == true,
    );
  }
}
