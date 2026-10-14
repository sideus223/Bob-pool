import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'preference_store.dart';

/// Connected mode always uses the server. No silent local fallback on failure.
class FirestorePreferenceStore implements PreferenceStore {
  final FirebaseFirestore firestore;
  final String? Function() currentUid;
  final PreferenceStore local;

  FirestorePreferenceStore({
    required this.firestore,
    required this.currentUid,
    PreferenceStore? local,
  }) : local = local ?? LocalPreferenceStore();

  void _checkAccount(String scope) {
    if (scope == 'guest' || scope == 'demo' || currentUid() != scope) {
      throw StateError('로그인 상태가 변경됐어요. 다시 로그인해 주세요.');
    }
  }

  DocumentReference<Map<String, dynamic>> _reference(String scope) =>
      firestore.doc('users/$scope/preferences/current');

  PreferenceData _decode(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 || data['values'] is! Map) {
      throw StateError('저장된 취향 정보의 형식을 확인할 수 없어요.');
    }
    return PreferenceData(Map<String, dynamic>.from(data['values'] as Map));
  }

  PreferenceData _import(PreferenceData legacy) {
    final values = <String, dynamic>{};
    final listKeys = {
      'favorites',
      for (final mood in ['기분 좋음', '기분좋음', '무난함', '우울함', '스트레스', '피곤함'])
        for (final type in ['added', 'removed', 'disliked']) '${type}_$mood',
    };
    for (final key in listKeys) {
      final list = legacy.getStringList(key);
      if (list != null) values[key] = list.toSet().toList();
    }
    for (final key in ['selections', 'interaction_history']) {
      if (legacy.values[key] is Map) values[key] = legacy.values[key];
    }
    // Malformed/unknown local fields stay in the backup, not in the cloud.
    return PreferenceData(values);
  }

  @override
  Future<PreferenceData> read(String scope) async {
    _checkAccount(scope);
    try {
      final snapshot = await _reference(scope)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      _checkAccount(scope);
      if (snapshot.exists) return _decode(snapshot.data()!);
      // The transaction rechecks existence, so another device's new document
      // wins over this device's old local copy.
      await update(scope, (_) async {});
      final imported = await _reference(scope)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      _checkAccount(scope);
      return _decode(imported.data()!);
    } on FirebaseException {
      throw StateError('서버에서 취향 정보를 불러오지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
    } on TimeoutException {
      throw StateError('서버 응답이 늦어지고 있어요. 연결을 확인하고 다시 시도해 주세요.');
    }
  }

  @override
  Future<void> update(
    String scope,
    Future<void> Function(PreferenceData) action,
  ) async {
    _checkAccount(scope);
    try {
      final reference = _reference(scope);
      // Read only this UID's V2 records; demo and unowned legacy data stay local.
      final legacy = _import(await local.read(scope));
      await firestore.runTransaction(
        (transaction) async {
          _checkAccount(scope);
          final snapshot = await transaction.get(reference);
          final state = snapshot.exists
              ? _decode(snapshot.data()!)
              : PreferenceData(legacy.values);
          await action(state);
          _checkAccount(scope);
          if (state.values.length > 64 ||
              jsonEncode(state.values).length > 200000) {
            throw StateError('취향 기록의 저장 한도를 초과했어요.');
          }
          transaction.set(reference, {
            'schemaVersion': 1,
            'values': state.values,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
        timeout: const Duration(seconds: 15),
        maxAttempts: 3,
      );
      _checkAccount(scope);
    } on FirebaseException {
      throw StateError('서버에 저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
    }
  }
}
