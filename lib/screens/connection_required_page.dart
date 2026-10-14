import 'package:flutter/material.dart';

class ConnectionRequiredPage extends StatelessWidget {
  const ConnectionRequiredPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('계정 연결 기능')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56),
            SizedBox(height: 20),
            Text(
              '로컬 데모를 체험하고 있어요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '게시판과 계정 관리는 Firebase 연결 버전에서 사용할 수 있어요.\n추천·찜·기분별 음식 관리·레시피는 지금 이용할 수 있어요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
