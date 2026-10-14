import 'package:cloud_firestore/cloud_firestore.dart';

class BoardPageResult<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
  const BoardPageResult(this.items, this.cursor, this.hasMore);
}
