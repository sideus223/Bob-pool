import 'package:flutter/material.dart';
import 'board_style.dart';
import 'board_avatar.dart';

class BoardCommentInput extends StatelessWidget {
  final String nickname;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  const BoardCommentInput({
    super.key,
    required this.nickname,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            BoardAvatar(nickname: nickname, radius: 18, fontSize: 13),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F3F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(
                      color: BoardStyle.primary,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              height: 42,
              child: submitting
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BoardStyle.primary,
                      ),
                    )
                  : FilledButton(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD7DB),
                        foregroundColor: BoardStyle.primary,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
