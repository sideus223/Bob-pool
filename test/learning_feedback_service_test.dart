import 'dart:math';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/models/learning_model.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/feedback_learning_engine.dart';
import 'package:bp2/services/firestore_preference_store.dart';
import 'package:bp2/services/local_recommend_service.dart';
import 'package:bp2/services/preference_store.dart';
import 'package:bp2/services/softmax_sampler.dart';
import 'package:bp2/services/user_menu_preference_service.dart';

class RetryingStore implements PreferenceStore {
  PreferenceData saved = PreferenceData();
  bool reject = false;
  @override
  Future<PreferenceData> read(String scope) async =>
      PreferenceData(saved.values);
  @override
  Future<void> update(
    String scope,
    Future<void> Function(PreferenceData) action,
  ) async {
    await action(PreferenceData(saved.values));
    final retried = PreferenceData(saved.values);
    await action(retried);
    if (reject) throw StateError('Server rejected transaction');
    saved = retried;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late String uid;
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    uid = 'alice';
    now = DateTime.utc(2026, 10, 12, 12);
    UserMenuPreferenceService.scopeProvider = () => uid;
    UserMenuPreferenceService.clock = () => now;
    UserMenuPreferenceService.store = FirestorePreferenceStore(
      firestore: db,
      currentUid: () => uid,
    );
  });
  tearDown(() {
    UserMenuPreferenceService.store = LocalPreferenceStore();
    UserMenuPreferenceService.scopeProvider = () => 'demo';
    UserMenuPreferenceService.clock = () => DateTime.now().toUtc();
  });
  RecommendationExposure exposure(int i, {String mood = '무난함'}) =>
      RecommendationExposure(
        id: 'event-$i',
        scope: uid,
        menuId: 'M${i % 4}',
        mood: mood,
        situation: '혼밥',
        budget: 10000,
        spicy: '상관없음',
        features: List.generate(
          LearningProfile.dimension,
          (j) => j == i % 4 ? 1.0 : 0.0,
        ),
        candidateIds: ['M0', 'M1', 'M2', 'M3'],
        drawProbability: 0.25,
        score: 30,
        learned: false,
        createdAt: now.millisecondsSinceEpoch,
      );
  Future<Map<String, dynamic>> state() async => Map<String, dynamic>.from(
    (await db.doc('users/$uid/preferences/current').get())
        .data()!['values']['learning'],
  );

  test(
    'transaction retries and failures never duplicate or partially save training',
    () async {
      final store = RetryingStore();
      UserMenuPreferenceService.store = store;
      final event = exposure(1);
      store.reject = true;
      await expectLater(
        UserMenuPreferenceService.recommendationFeedback(
          event,
          RecommendationFeedback.select,
        ),
        throwsStateError,
      );
      expect(store.saved.values, isEmpty);
      store.reject = false;
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.select,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.select,
      );
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.learning.sampleCount, 1);
      expect(snapshot.history['M1']!.selectionCount, 1);
      expect(snapshot.history['M1']!.recommendationCount, 1);
    },
  );

  test(
    'explicit re-addition removes the menu negative learning in that mood only',
    () async {
      await UserMenuPreferenceService.recommendationFeedback(
        exposure(1),
        RecommendationFeedback.dislike,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        exposure(5, mood: '스트레스'),
        RecommendationFeedback.dislike,
      );
      await UserMenuPreferenceService.addMoodForMenu(menuId: 'M1', mood: '무난함');
      expect((await state())['negatives'], 1);
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).dislikes,
        isEmpty,
      );
      expect((await UserMenuPreferenceService.snapshot('스트레스')).dislikes, {
        'M1',
      });
    },
  );

  test(
    'malformed event is preserved on failure and reset recovers without losing favorites',
    () async {
      await UserMenuPreferenceService.addFavoriteMenu('keep');
      await UserMenuPreferenceService.recordExposure(exposure(1));
      final broken = await state();
      (broken['events'] as List).single['drawProbability'] = 0;
      await db.doc('users/alice/preferences/current').update({
        'values.learning': broken,
      });
      await expectLater(
        UserMenuPreferenceService.recommendationFeedback(
          exposure(2),
          RecommendationFeedback.select,
        ),
        throwsFormatException,
      );
      expect((await state())['events'], hasLength(1));
      await UserMenuPreferenceService.resetLearning();
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.favorites, {'keep'});
      expect(snapshot.learning.sampleCount, 0);
    },
  );

  test(
    'exposure is not a label; like and select form one sample, retries are idempotent',
    () async {
      final event = exposure(1);
      await UserMenuPreferenceService.recordExposure(event);
      await UserMenuPreferenceService.recordExposure(event);
      expect((await state())['sampleCount'], 0);
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.like,
      );
      await Future.wait(
        List.generate(
          3,
          (_) => UserMenuPreferenceService.recommendationFeedback(
            event,
            RecommendationFeedback.select,
          ),
        ),
      );
      expect((await state())['sampleCount'], 1);
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.history['M1']!.recommendationCount, 1);
      expect(snapshot.selections['M1'], 1);
      expect(snapshot.favorites, {'M1'});
      final stored = ((await state())['events'] as List).single;
      expect(stored['candidateIds'], ['M0', 'M1', 'M2', 'M3']);
      expect(stored['drawProbability'], 0.25);
      expect(stored['budget'], 10000);
      expect(stored['features'], event.features);
    },
  );

  test(
    'unlike retracts a like; selecting remains positive; dislike wins',
    () async {
      final event = exposure(1);
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.like,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.unlike,
      );
      expect((await state())['sampleCount'], 0);
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.select,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.unlike,
      );
      expect((await state())['positives'], 1);
      await UserMenuPreferenceService.recommendationFeedback(
        event,
        RecommendationFeedback.dislike,
      );
      expect((await state())['sampleCount'], 1);
      expect((await state())['negatives'], 1);
      expect((await UserMenuPreferenceService.snapshot('무난함')).dislikes, {
        'M1',
      });
    },
  );

  test(
    'model survives new device and account switch never trains another user',
    () async {
      for (var i = 0; i < 8; i++) {
        await UserMenuPreferenceService.recommendationFeedback(
          exposure(i),
          i.isEven
              ? RecommendationFeedback.select
              : RecommendationFeedback.dislike,
        );
        now = now.add(const Duration(seconds: 1));
      }
      final before = (await UserMenuPreferenceService.snapshot('무난함')).learning;
      expect(before.ready, isTrue);
      final oldExposure = exposure(9);
      SharedPreferences.setMockInitialValues({});
      UserMenuPreferenceService.store = FirestorePreferenceStore(
        firestore: db,
        currentUid: () => uid,
      );
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.weights,
        before.weights,
      );
      uid = 'bob';
      await expectLater(
        UserMenuPreferenceService.recommendationFeedback(
          oldExposure,
          RecommendationFeedback.select,
        ),
        throwsStateError,
      );
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.sampleCount,
        0,
      );
      uid = 'alice';
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.sampleCount,
        8,
      );
    },
  );

  test(
    'recent window is bounded and stale events stop affecting the model',
    () async {
      for (var i = 0; i < 66; i++) {
        await UserMenuPreferenceService.recordExposure(exposure(i));
        now = now.add(const Duration(seconds: 1));
      }
      expect((await state())['events'], hasLength(64));
      final latest = exposure(100);
      await UserMenuPreferenceService.recommendationFeedback(
        latest,
        RecommendationFeedback.like,
      );
      now = now.add(const Duration(days: 31));
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.sampleCount,
        0,
      );
      await expectLater(
        UserMenuPreferenceService.recordExposure(latest),
        throwsStateError,
      );
      await UserMenuPreferenceService.recordExposure(exposure(101));
      expect((await state())['events'], hasLength(1));
    },
  );

  test(
    'unanswered browsing cannot evict retained reactions and later feedback still works',
    () async {
      final reacted = <String>{};
      late RecommendationExposure evicted;
      for (var i = 0; i < 8; i++) {
        final item = exposure(i);
        reacted.add(item.id);
        await UserMenuPreferenceService.recommendationFeedback(
          item,
          i.isEven
              ? RecommendationFeedback.like
              : RecommendationFeedback.dislike,
        );
        now = now.add(const Duration(seconds: 1));
      }
      final weights = (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).learning.weights;
      late RecommendationExposure latest;
      for (var i = 8; i < 90; i++) {
        latest = exposure(i);
        if (i == 8) evicted = latest;
        await UserMenuPreferenceService.recordExposure(latest);
        now = now.add(const Duration(seconds: 1));
      }
      final retained = (await state())['events'] as List;
      expect(retained, hasLength(64));
      expect(retained.where((e) => reacted.contains(e['id'])), hasLength(8));
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.learning.sampleCount, 8);
      expect(snapshot.learning.weights, weights);
      final previousCount =
          snapshot.history[evicted.menuId]!.recommendationCount;
      await expectLater(
        UserMenuPreferenceService.recordExposure(evicted),
        throwsStateError,
      );
      expect(
        (await UserMenuPreferenceService.snapshot(
          '무난함',
        )).history[evicted.menuId]!.recommendationCount,
        previousCount,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        latest,
        RecommendationFeedback.select,
      );
      await UserMenuPreferenceService.recommendationFeedback(
        latest,
        RecommendationFeedback.select,
      );
      expect((await state())['sampleCount'], 9);
      final latestCount = (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).history[latest.menuId]!.selectionCount;
      expect(latestCount, 1);
    },
  );

  test(
    'one-sided early learning survives a new store using the versioned schema',
    () async {
      for (var i = 0; i < 4; i++) {
        await UserMenuPreferenceService.recommendationFeedback(
          exposure(i),
          RecommendationFeedback.like,
        );
        now = now.add(const Duration(seconds: 1));
      }
      final before = (await UserMenuPreferenceService.snapshot('무난함')).learning;
      expect(before.ready, isTrue);
      expect(before.negatives, 0);
      expect((await state())['version'], LearningProfile.version);
      UserMenuPreferenceService.store = FirestorePreferenceStore(
        firestore: db,
        currentUid: () => uid,
      );
      final restored = (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).learning;
      expect(restored.ready, isTrue);
      expect(restored.weights, before.weights);
    },
  );

  test(
    'retention reserves recent pending exposures while protecting up to 48 reactions',
    () async {
      for (var i = 0; i < 64; i++) {
        await UserMenuPreferenceService.recommendationFeedback(
          exposure(i),
          i.isEven
              ? RecommendationFeedback.like
              : RecommendationFeedback.dislike,
        );
        now = now.add(const Duration(seconds: 1));
      }
      expect((await state())['sampleCount'], 64);
      for (var i = 64; i < 84; i++) {
        await UserMenuPreferenceService.recordExposure(exposure(i));
        now = now.add(const Duration(seconds: 1));
      }
      expect((await state())['events'], hasLength(64));
      expect((await state())['sampleCount'], 48);
      expect(
        ((await state())['events'] as List).where((e) => e['id'] == 'event-0'),
        isEmpty,
      );
    },
  );

  test(
    'mood reset forgets related learning and favorite removal retracts likes',
    () async {
      await UserMenuPreferenceService.recommendationFeedback(
        exposure(1),
        RecommendationFeedback.like,
      );
      await UserMenuPreferenceService.removeFavoriteMenu('M1');
      expect((await state())['sampleCount'], 0);
      await UserMenuPreferenceService.recommendationFeedback(
        exposure(2, mood: '스트레스'),
        RecommendationFeedback.dislike,
      );
      await UserMenuPreferenceService.clearMoodCustomizations('스트레스');
      expect((await state())['negatives'], 0);
      expect(
        ((await state())['events'] as List).any((e) => e['mood'] == '스트레스'),
        isFalse,
      );
      await UserMenuPreferenceService.resetLearning();
      expect((await state())['events'], isEmpty);
    },
  );

  test(
    'a future device timestamp does not permanently reject new exposures',
    () async {
      final originalNow = now;
      now = now.add(const Duration(days: 3));
      await UserMenuPreferenceService.recordExposure(exposure(1));
      now = originalNow;
      await UserMenuPreferenceService.recordExposure(exposure(5));
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.history['M1']!.lastRecommendedAt, originalNow);
      expect(snapshot.history['M1']!.lastExposureId, 'event-5');
      expect((await state())['events'], hasLength(1));
    },
  );

  test(
    'legacy reactions are reconstructed on read and migrated atomically on write',
    () async {
      final menus = await LocalRecommendService.getAllMenus();
      final prior = {
        ...exposure(1).toMap(),
        'id': 'legacy',
        'menuId': 'M001',
        'candidateIds': ['M001', 'M002'],
        'features': List.filled(64, 0.0),
        'liked': true,
      }..remove('featureVersion');
      final legacy = {
        'version': 1,
        'weights': List.filled(64, 3.0),
        'sampleCount': 1,
        'positives': 1,
        'negatives': 0,
        'distinctMenus': 1,
        'events': [prior],
      };
      await db.doc('users/alice/preferences/current').set({
        'schemaVersion': 1,
        'values': {
          'favorites': ['M001'],
          'learning': legacy,
        },
        'updatedAt': now,
      });
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.learning.modelVersion, 2);
      expect(snapshot.learning.sampleCount, 1);
      expect((await state())['version'], 1); // Read has no server write.
      final expectedFeatures = FeedbackLearningEngine.features(
        menus.first,
        const RecommendationRequest(
          mood: '무난함',
          situation: '혼밥',
          budget: 10000,
        ),
      );
      expect(
        snapshot.learning.weights,
        FeedbackLearningEngine.fit([
          {...prior, 'features': expectedFeatures},
        ]).weights,
      );
      await UserMenuPreferenceService.recordExposure(exposure(2));
      final migrated = await state();
      expect(migrated['version'], 2);
      final restored = (migrated['events'] as List).singleWhere(
        (e) => e['id'] == 'legacy',
      );
      expect(restored['features'], expectedFeatures);
      expect(restored['featureVersion'], 2);
      expect(restored['liked'], isTrue);
      expect(restored['drawProbability'], prior['drawProbability']);
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['M001']);
      uid = 'bob';
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.sampleCount,
        0,
      );
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
    },
  );

  test(
    'legacy migration failure preserves the original model and other preferences',
    () async {
      final store = RetryingStore();
      UserMenuPreferenceService.store = store;
      final event = {
        ...exposure(1).toMap(),
        'menuId': 'M001',
        'candidateIds': ['M001'],
        'features': List.filled(64, 0.0),
        'liked': true,
      }..remove('featureVersion');
      store.saved.values.addAll({
        'favorites': ['keep'],
        'learning': {
          'version': 1,
          'weights': List.filled(64, 0.0),
          'sampleCount': 1,
          'positives': 1,
          'negatives': 0,
          'distinctMenus': 1,
          'events': [event],
        },
      });
      store.reject = true;
      await expectLater(
        UserMenuPreferenceService.recordExposure(exposure(2)),
        throwsStateError,
      );
      expect((store.saved.values['learning'] as Map)['version'], 1);
      expect(store.saved.values['favorites'], ['keep']);
      store.reject = false;
      await UserMenuPreferenceService.recordExposure(exposure(2));
      expect((store.saved.values['learning'] as Map)['version'], 2);
      expect((store.saved.values['learning'] as Map)['events'], hasLength(2));
    },
  );

  test(
    'explicit reset recovers corrupt legacy learning without clearing favorites',
    () async {
      await db.doc('users/alice/preferences/current').set({
        'schemaVersion': 1,
        'values': {
          'favorites': ['keep'],
          'learning': {'version': 1, 'weights': []},
        },
        'updatedAt': now,
      });
      await expectLater(
        UserMenuPreferenceService.snapshot('무난함'),
        throwsFormatException,
      );
      await UserMenuPreferenceService.resetLearning();
      expect((await state())['version'], 2);
      expect((await state())['events'], isEmpty);
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['keep']);
    },
  );

  test('an unsupported model fails without overwriting preferences', () async {
    await db.doc('users/alice/preferences/current').set({
      'schemaVersion': 1,
      'values': {
        'favorites': ['keep'],
        'learning': {'version': 99},
      },
      'updatedAt': DateTime.now(),
    });
    await expectLater(
      UserMenuPreferenceService.recordExposure(exposure(1)),
      throwsFormatException,
    );
    final values = (await db.doc('users/alice/preferences/current').get())
        .data()!['values'];
    expect(values['favorites'], ['keep']);
    expect(values['learning'], {'version': 99});
  });

  test(
    'draw log uses the actual filtered pool and mixed sampling probability',
    () async {
      const request = RecommendationRequest(
        mood: '무난함',
        situation: '혼밥',
        budget: 25000,
      );
      final candidates = await LocalRecommendService.rank(request);
      final choice = LocalRecommendService.pickWithExposure(
        candidates,
        request,
        random: Random(42),
      );
      final expected = SoftmaxSampler()
          .distribution(
            candidates,
            explorationRate: SoftmaxSampler.defaultExplorationRate,
          )
          .firstWhere(
            (p) => p.candidate.menu.menuId == choice.result.menu.menuId,
          )
          .probability;
      expect(choice.exposure.drawProbability, expected);
      expect(choice.exposure.toMap()['policy'], 'rules-v2');
      expect(choice.exposure.toMap()['policyVersion'], 3);
      expect(
        FeedbackLearningEngine.validEvent(choice.exposure.toMap()),
        isTrue,
      );
      final legacy = Map<String, dynamic>.from(choice.exposure.toMap())
        ..remove('policyVersion');
      expect(FeedbackLearningEngine.validEvent(legacy), isTrue);
      expect(
        FeedbackLearningEngine.validEvent({...legacy, 'policyVersion': 99}),
        isFalse,
      );
      expect(
        choice.exposure.candidateIds,
        candidates.map((r) => r.menu.menuId).toList(),
      );
      expect(
        choice.exposure.features,
        FeedbackLearningEngine.features(choice.result.menu, request),
      );
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).history,
        isEmpty,
      );
      await UserMenuPreferenceService.recordExposure(choice.exposure);
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).learning.sampleCount,
        0,
      );
      uid = 'bob';
      expect(
        () => LocalRecommendService.pickWithExposure(candidates, request),
        throwsStateError,
      );
    },
  );
}
