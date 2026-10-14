import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/post_model.dart';
import 'package:bp2/models/comment_model.dart';
import 'package:bp2/widgets/board/board_post_card.dart';
import 'package:bp2/widgets/board/board_comment_item.dart';
import 'package:bp2/widgets/board/board_comments_section.dart';
import 'package:bp2/widgets/board/board_comment_input.dart';

void main() {
  final post = PostModel(
    id: 'p',
    title: '오늘의 한 끼',
    content: '게시글 내용',
    authorUid: 'alice',
    authorNickname: '작성자',
  );
  final comment = CommentModel(
    id: 'c',
    content: '댓글 내용',
    authorUid: 'alice',
    authorNickname: '작성자',
  );
  Future<void> show(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'post card retains content and author-only edit/delete callbacks',
    (tester) async {
      int edits = 0, deletes = 0, likes = 0;
      await show(
        tester,
        BoardPostCard(
          post: post,
          isLiked: false,
          isAuthor: true,
          onEdit: () => edits++,
          onDelete: () => deletes++,
          onLike: () => likes++,
        ),
      );
      expect(find.text('오늘의 한 끼'), findsOneWidget);
      expect(find.text('게시글 내용'), findsOneWidget);
      await tester.tap(find.byTooltip('게시글 수정'));
      await tester.tap(find.byTooltip('게시글 삭제'));
      await tester.tap(find.byIcon(Icons.favorite_border));
      expect([edits, deletes, likes], [1, 1, 1]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('another account has no post edit/delete controls', (
    tester,
  ) async {
    await show(
      tester,
      BoardPostCard(
        post: post,
        isLiked: true,
        isAuthor: false,
        onEdit: () {},
        onDelete: () {},
        onLike: () {},
      ),
    );
    expect(find.byTooltip('게시글 수정'), findsNothing);
    expect(find.byTooltip('게시글 삭제'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
  testWidgets('comment menu delegates edits/deletes only for its author', (
    tester,
  ) async {
    String? edited, deleted;
    await show(
      tester,
      BoardCommentItem(
        comment: comment,
        currentUid: 'alice',
        onEdit: (c) => edited = c.id,
        onDelete: (c) => deleted = c.id,
      ),
    );
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(edited, 'c');
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(deleted, 'c');
    await show(
      tester,
      BoardCommentItem(
        comment: comment,
        currentUid: 'bob',
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });
  testWidgets('comments section preserves empty state and stream contents', (
    tester,
  ) async {
    await show(
      tester,
      BoardCommentsSection(
        commentsStream: Stream.value([]),
        currentUid: 'alice',
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    expect(find.text('아직 댓글이 없습니다.'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget);
    await show(
      tester,
      BoardCommentsSection(
        commentsStream: Stream.value([comment]),
        currentUid: 'bob',
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    expect(find.text('댓글 내용'), findsOneWidget);
    expect(find.text('1개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('comment composer keeps text and submit/progress behavior', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    int submissions = 0;
    await show(
      tester,
      BoardCommentInput(
        nickname: '나',
        controller: controller,
        submitting: false,
        onSubmit: () => submissions++,
      ),
    );
    await tester.enterText(find.byType(TextField), '새 댓글');
    await tester.tap(find.byIcon(Icons.send_rounded));
    expect(controller.text, '새 댓글');
    expect(submissions, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardCommentInput(
            nickname: '나',
            controller: controller,
            submitting: true,
            onSubmit: () => submissions++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
