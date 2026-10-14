import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/menu_model.dart';

class MenuCatalogService {
  static List<MenuModel>? _cached;
  static Future<List<MenuModel>>? _loading;
  static Future<List<MenuModel>> getAll() async {
    if (_cached != null) return _cached!;
    return _loading ??= _load();
  }

  static Future<List<MenuModel>> _load() async {
    try {
      final data = await rootBundle.loadString(
        'assets/data/menus_dataset.json',
      );
      final rows = jsonDecode(data) as List;
      final menus = rows
          .map((row) => MenuModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      if (menus.map((m) => m.menuId).toSet().length != menus.length ||
          menus.any((m) => !m.foodTraits.isComplete)) {
        throw const FormatException('Incomplete menu catalog');
      }
      return _cached = List.unmodifiable(menus);
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  static Future<Map<String, MenuModel>> byId() async =>
      Map.unmodifiable({for (final menu in await getAll()) menu.menuId: menu});
}
