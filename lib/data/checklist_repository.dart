import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'checklist_template.dart';

class ChecklistRepository {
  static final Map<String, ChecklistTemplate> _cache = {};

  static Future<ChecklistTemplate> loadPv() => _load('assets/regulatory/checklist_pv.json', 'pv');

  static Future<ChecklistTemplate> loadBatterie() =>
      _load('assets/regulatory/checklist_batterie.json', 'batterie');

  static Future<ChecklistTemplate> _load(String assetPath, String cacheKey) async {
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final template = ChecklistTemplate.fromJson(json);
    _cache[cacheKey] = template;
    return template;
  }
}
