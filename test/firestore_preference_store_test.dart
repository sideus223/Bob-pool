import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/services/firestore_preference_store.dart';
import 'package:bp2/services/preference_store.dart';
import 'package:bp2/services/user_menu_preference_service.dart';

class DelayedLocalStore extends LocalPreferenceStore {
  final ready = Completer<void>();
  @override
  Future<PreferenceData> read(String scope) async {
    await ready.future;
    return super.read(scope);
  }
}

class UnavailableStore implements PreferenceStore {
  @override
  Future<PreferenceData> read(String scope) async =>
      throw StateError('offline');
  @override
  Future<void> update(
    String scope,
    Future<void> Function(PreferenceData) action,
  ) async => throw StateError('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore database;
  late String? uid;
  late FirestorePreferenceStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = FakeFirebaseFirestore();
    uid = 'alice';
    store = FirestorePreferenceStore(
      firestore: database,
      currentUid: () => uid,
    );
    UserMenuPreferenceService.store = store;
    UserMenuPreferenceService.scopeProvider = () => uid ?? 'guest';
    UserMenuPreferenceService.clock = () => DateTime.utc(2026, 10, 11, 12);
  });
  tearDown(() {
    UserMenuPreferenceService.store = LocalPreferenceStore();
    UserMenuPreferenceService.scopeProvider = () => 'demo';
    UserMenuPreferenceService.clock = () => DateTime.now().toUtc();
  });

  test(
    'first import includes only current UID V2 data and preserves backup',
    () async {
      SharedPreferences.setMockInitialValues({
        'bap_pool_v2_alice_favorites': ['A'],
        'bap_pool_v2_alice_selections': '{"A":2}',
        'bap_pool_v2_bob_favorites': ['B'],
        'bap_pool_v2_demo_favorites': ['D'],
        'liked_menus_': ['unowned'],
      });
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.favorites, {'A'});
      expect(snapshot.selections, {'A': 2});
      final cloud =
          (await database.doc('users/alice/preferences/current').get()).data()!;
      expect(cloud['values'], {
        'favorites': ['A'],
        'selections': {'A': 2},
      });
      expect(cloud['updatedAt'], isA<Timestamp>());
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'bap_pool_v2_alice_favorites',
        ),
        ['A'],
      );
      expect(
        (await database.doc('users/bob/preferences/current').get()).exists,
        isFalse,
      );
    },
  );

  test(
    'cloud data survives a new device and overrides stale local records',
    () async {
      await UserMenuPreferenceService.addFavoriteMenu('A');
      await UserMenuPreferenceService.recordSelection('A');
      SharedPreferences.setMockInitialValues({
        'bap_pool_v2_alice_favorites': ['stale'],
      });
      UserMenuPreferenceService.store = FirestorePreferenceStore(
        firestore: database,
        currentUid: () => uid,
      );
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['A']);
      expect((await UserMenuPreferenceService.snapshot('무난함')).selections, {
        'A': 1,
      });
      await UserMenuPreferenceService.clearFavoriteMenus();
      UserMenuPreferenceService.store = FirestorePreferenceStore(
        firestore: database,
        currentUid: () => uid,
      );
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
    },
  );

  test(
    'server round trip retains moods, dislike, exposure and selection',
    () async {
      await UserMenuPreferenceService.addMoodForMenu(menuId: 'A', mood: '무난함');
      await UserMenuPreferenceService.removeMoodForMenu(
        menuId: 'B',
        mood: '무난함',
      );
      await UserMenuPreferenceService.dislikeMenuForMood(
        menuId: 'C',
        mood: '무난함',
      );
      await UserMenuPreferenceService.recordRecommendation('A');
      await UserMenuPreferenceService.recordSelection('A');
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.added, {'A'});
      expect(snapshot.removed, {'B'});
      expect(snapshot.dislikes, {'C'});
      expect(snapshot.history['A']!.recommendationCount, 1);
      expect(snapshot.history['A']!.selectionCount, 1);
      expect(
        snapshot.history['A']!.lastSelectedAt,
        DateTime.utc(2026, 10, 11, 12),
      );
      await UserMenuPreferenceService.clearMoodCustomizations('무난함');
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).dislikes,
        isEmpty,
      );
    },
  );

  test(
    'account switch is isolated and unauthenticated access is rejected',
    () async {
      await UserMenuPreferenceService.addFavoriteMenu('A');
      uid = 'bob';
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
      await UserMenuPreferenceService.addFavoriteMenu('B');
      uid = 'alice';
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['A']);
      uid = null;
      await expectLater(
        UserMenuPreferenceService.getFavoriteMenuIds(),
        throwsStateError,
      );
      await expectLater(
        UserMenuPreferenceService.addFavoriteMenu('C'),
        throwsStateError,
      );
    },
  );

  test(
    'sign out during an operation cannot redirect the write to another UID',
    () async {
      final local = DelayedLocalStore();
      UserMenuPreferenceService.store = FirestorePreferenceStore(
        firestore: database,
        currentUid: () => uid,
        local: local,
      );
      final pending = UserMenuPreferenceService.addFavoriteMenu('A');
      final result = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      uid = 'bob';
      local.ready.complete();
      await result;
      expect(
        (await database.doc('users/alice/preferences/current').get()).exists,
        isFalse,
      );
      expect(
        (await database.doc('users/bob/preferences/current').get()).exists,
        isFalse,
      );
    },
  );

  test('serialized server writes retain every feedback count', () async {
    await Future.wait(
      List.generate(12, (_) => UserMenuPreferenceService.recordSelection('A')),
    );
    expect(
      (await UserMenuPreferenceService.snapshot('무난함')).selections['A'],
      12,
    );
  });

  test(
    'failed server operations never fall back to local data or persist a tap',
    () async {
      SharedPreferences.setMockInitialValues({
        'bap_pool_v2_alice_favorites': ['local'],
      });
      UserMenuPreferenceService.store = UnavailableStore();
      await expectLater(
        UserMenuPreferenceService.getFavoriteMenuIds(),
        throwsStateError,
      );
      await expectLater(
        UserMenuPreferenceService.addFavoriteMenu('new'),
        throwsStateError,
      );
      expect(
        (await LocalPreferenceStore().read('alice')).getStringList('favorites'),
        ['local'],
      );
      UserMenuPreferenceService.store = store;
      await UserMenuPreferenceService.addFavoriteMenu('recovered');
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), [
        'local',
        'recovered',
      ]);
    },
  );

  test('malformed local fields do not block the first import', () async {
    SharedPreferences.setMockInitialValues({
      'bap_pool_v2_alice_favorites': ['A', 'A'],
      'bap_pool_v2_alice_interaction_history': '{broken',
      'bap_pool_v2_alice_selections': '[]',
      'bap_pool_v2_alice_unknown': 'true',
    });
    expect((await UserMenuPreferenceService.snapshot('무난함')).favorites, {'A'});
    final cloud = (await database.doc('users/alice/preferences/current').get())
        .data()!;
    expect(cloud['values'], {
      'favorites': ['A'],
    });
    expect(
      (await SharedPreferences.getInstance()).getString(
        'bap_pool_v2_alice_interaction_history',
      ),
      '{broken',
    );
  });

  test(
    'unexpected cloud schema fails without overwriting the document',
    () async {
      final reference = database.doc('users/alice/preferences/current');
      await reference.set({
        'schemaVersion': 99,
        'values': {},
        'updatedAt': Timestamp.now(),
      });
      await expectLater(
        UserMenuPreferenceService.getFavoriteMenuIds(),
        throwsStateError,
      );
      await expectLater(
        UserMenuPreferenceService.addFavoriteMenu('A'),
        throwsStateError,
      );
      expect((await reference.get()).data()!['schemaVersion'], 99);
    },
  );
}
