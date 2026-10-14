import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bp2/models/post_model.dart';

const runId = String.fromEnvironment('BOARD_COMPARE_RUN_ID');
const postCountsArgument = String.fromEnvironment(
  'BOARD_COMPARE_COUNTS',
  defaultValue: '1000',
);
final postCounts = postCountsArgument.split(',').map(int.parse).toList();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (postCounts.isEmpty ||
      postCounts.toSet().length != postCounts.length ||
      postCounts.any((postCount) => ![20, 100, 500, 1000].contains(postCount))) {
    throw ArgumentError('Unsupported comparison dataset sizes');
  }
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  runApp(const MaterialApp(home: ComparisonPage()));
}

class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});
  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  String _status = '로그인 세션 확인 중';
  String? _uid;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;
    if (user == null) {
      setState(() => _status = '기존 앱에서 로그인이 필요합니다.');
      return;
    }
    _uid = user.uid;
    // Operator-only control data is stored in tmp, never in public metrics.
    debugPrint('BOARD_COMPARE_CONTROL ${jsonEncode({'uid': _uid})}');
    setState(() => _status = '테스트 데이터 준비를 기다리고 있습니다.');
  }

  Future<void> _run() async {
    if (_running || _uid == null || runId.isEmpty) return;
    setState(() => _running = true);
    var sequence = 0;
    var datasetPosts = 0;
    try {
      for (final count in postCounts) {
        datasetPosts = count;
        sequence = 0;
        final datasetPath = postCounts.length == 1 && count == 1000
            ? ''
            : 'datasets/$count/';
        final posts = FirebaseFirestore.instance.collection(
          '_boardLatency/$_uid/runs/$runId/${datasetPath}posts',
        );
        for (var pair = 1; pair <= 24; pair++) {
          final order = pair.isOdd
              ? ['original', 'current']
              : ['current', 'original'];
          for (final variant in order) {
            sequence++;
            if (!mounted) return;
            setState(
              () => _status =
                  '게시글 $count개 · ${pair <= 4 ? '예열' : '측정'} $pair / 24\n${variant == 'original' ? '원래 전체 구독' : '현재 20개 조회'}',
            );
            final Query<Map<String, dynamic>> query = variant == 'original'
                ? posts.orderBy('createdAt', descending: true)
                : posts
                      .where('deleted', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .orderBy(FieldPath.documentId)
                      .limit(20);
            final timer = Stopwatch()..start();
            final snapshot = variant == 'original'
                ? await query
                      .snapshots(includeMetadataChanges: true)
                      .firstWhere((value) => !value.metadata.isFromCache)
                      .timeout(const Duration(seconds: 30))
                : await query
                      .get(const GetOptions(source: Source.server))
                      .timeout(const Duration(seconds: 30));
            timer.stop();
            final decode = Stopwatch()..start();
            final models = snapshot.docs
                .map(PostModel.fromFirestore)
                .toList(growable: false);
            decode.stop();
            final expected = variant == 'original' ? count : 20;
            if (snapshot.metadata.isFromCache || models.length != expected) {
              throw StateError('Unexpected source or document count');
            }
            debugPrint(
              'BOARD_COMPARE ${jsonEncode({'event': 'sample', 'dataset_posts': count, 'sequence': sequence, 'pair': pair, 'variant': variant, 'warmup': pair <= 4, 'query_us': timer.elapsedMicroseconds, 'decode_us': decode.elapsedMicroseconds, 'total_us': timer.elapsedMicroseconds + decode.elapsedMicroseconds, 'documents': models.length, 'from_cache': snapshot.metadata.isFromCache})}',
            );
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        debugPrint(
          'BOARD_COMPARE ${jsonEncode({'event': 'complete', 'dataset_posts': count, 'samples': sequence})}',
        );
      }
      debugPrint(
        'BOARD_COMPARE ${jsonEncode({'event': 'complete_all', 'datasets': postCounts, 'samples': 48 * postCounts.length})}',
      );
      if (mounted) {
        setState(
          () => _status = '비교 측정 완료\n${48 * postCounts.length}회 서버 응답 기록',
        );
      }
    } catch (error) {
      debugPrint(
        'BOARD_COMPARE ${jsonEncode({'event': 'error', 'dataset_posts': datasetPosts, 'sequence': sequence, 'type': error.runtimeType.toString(), 'code': error is FirebaseException ? error.code : 'comparison-failed'})}',
      );
      if (mounted) setState(() => _status = '측정을 중단했습니다. 로그를 확인합니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('밥풀 게시판 전후 비교')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _uid != null && !_running ? _run : null,
              child: const Text('비교 측정 시작'),
            ),
          ],
        ),
      ),
    ),
  );
}
