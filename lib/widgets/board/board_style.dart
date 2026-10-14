import 'package:flutter/material.dart';

class BoardStyle {
  static const primary = Color(0xFFFD5D69);
  static const background = Color(0xFFFFFDF9);
  static const text = Color(0xFF32201C);
  static const softPink = Color(0xFFFFEEF0);
  static const line = Color(0xFFF1E8E4);
}

String boardFormatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '방금 전';

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) return '방금 전';
  if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
  if (difference.inHours < 24) return '${difference.inHours}시간 전';
  if (difference.inDays < 7) return '${difference.inDays}일 전';

  return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
}
