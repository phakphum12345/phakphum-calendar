import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/swap_request.dart';

class SwapRequestService {
  static const _key = 'swap_requests';

  Future<List<SwapRequest>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    return raw.map((r) {
      try {
        return SwapRequest.fromJson(Map<String, Object?>.from(jsonDecode(r) as Map));
      } catch (_) {
        return null;
      }
    }).whereType<SwapRequest>().toList();
  }

  Future<void> save(SwapRequest req) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.insert(0, jsonEncode(req.toJson()));
    await prefs.setStringList(_key, list.take(200).toList());
  }

  Future<void> update(SwapRequest req) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    final decoded = list.map((e) {
      try {
        return Map<String, Object?>.from(jsonDecode(e) as Map);
      } catch (_) {
        return null;
      }
    }).whereType<Map<String, Object?>>().toList();
    final idx = decoded.indexWhere((m) => m['id'] == req.id);
    if (idx == -1) return save(req);
    decoded[idx] = req.toJson();
    await prefs.setStringList(_key, decoded.map((m) => jsonEncode(m)).toList());
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    final filtered = list.where((e) {
      try {
        final m = Map<String, Object?>.from(jsonDecode(e) as Map);
        return m['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, filtered);
  }
}
