import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/upload_task.dart';

/// Persists unfinished upload tasks so the queue survives app restarts
/// (offline retry). Only path-backed tasks are stored — in-memory tasks
/// (web) are session-scoped.
class UploadQueueStore {
  static const _key = 'allpics.upload_queue.v1';

  Future<void> save(List<UploadTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = tasks
        .where((t) =>
            t.status != UploadTaskStatus.success && t.filePath != null)
        .map((t) => t.toJson())
        .toList();
    if (pending.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(pending));
    }
  }

  Future<List<UploadTask>> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UploadTask.fromJson(e as Map<String, dynamic>))
          .whereType<UploadTask>()
          .toList();
    } catch (_) {
      await prefs.remove(_key);
      return const [];
    }
  }
}
