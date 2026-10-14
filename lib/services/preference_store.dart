import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A detached document: callbacks may be retried without modifying app state.
class PreferenceData {
  final Map<String, dynamic> values;
  PreferenceData([Map<String, dynamic>? values])
    : values = values == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(jsonEncode(values)) as Map);

  List<String>? getStringList(String key) {
    final value = values[key];
    return value is List ? value.whereType<String>().toList() : null;
  }

  String? getString(String key) {
    final value = values[key];
    return value == null
        ? null
        : value is String
        ? value
        : jsonEncode(value);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = List<String>.of(value);
    return true;
  }

  Future<bool> setString(String key, String value) async {
    values[key] = jsonDecode(value);
    return true;
  }

  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

abstract class PreferenceStore {
  Future<PreferenceData> read(String scope);
  Future<void> update(
    String scope,
    Future<void> Function(PreferenceData) action,
  );
}

/// Demo storage and the source of the first account-scoped cloud import.
class LocalPreferenceStore implements PreferenceStore {
  String _prefix(String scope) => 'bap_pool_v2_${Uri.encodeComponent(scope)}_';

  @override
  Future<PreferenceData> read(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefix(scope);
    final values = <String, dynamic>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final value = prefs.get(key);
      if (value is List<String>) {
        values[key.substring(prefix.length)] = List<String>.of(value);
      } else if (value is String) {
        try {
          values[key.substring(prefix.length)] = jsonDecode(value);
        } on FormatException {
          values[key.substring(prefix.length)] = value;
        }
      }
    }
    return PreferenceData(values);
  }

  @override
  Future<void> update(
    String scope,
    Future<void> Function(PreferenceData) action,
  ) async {
    final before = await read(scope);
    final after = PreferenceData(before.values);
    await action(after);
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefix(scope);
    for (final key in {...before.values.keys, ...after.values.keys}) {
      if (jsonEncode(before.values[key]) == jsonEncode(after.values[key])) {
        continue;
      }
      final value = after.values[key];
      final saved = !after.values.containsKey(key)
          ? await prefs.remove('$prefix$key')
          : value is List<String>
          ? await prefs.setStringList('$prefix$key', value)
          : await prefs.setString('$prefix$key', jsonEncode(value));
      if (!saved) throw StateError('저장에 실패했습니다.');
    }
  }
}
