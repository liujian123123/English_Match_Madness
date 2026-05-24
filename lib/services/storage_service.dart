import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_pair.dart';
import '../models/session_result.dart';
import '../models/word_stats.dart';

class StorageService {
  static const _importedWordsKey = 'imported_words';
  static const _wrongWordsKey = 'wrong_words';
  static const _lastResultKey = 'last_result';
  static const _totalImportedKey = 'total_imported_count';
  static const _wordStatsKey = 'word_stats';

  static const _backupFilename = 'wordbank.json';
  static const _channel = MethodChannel('com.matchmadness.match_madness/file');

  /// 请求存储权限（Android 运行时权限）
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('requestStoragePermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // --- File-based storage (persists across reinstalls via MediaStore) ---

  /// 主存储：应用文档目录（Android 自动备份会包含此目录，但卸载重装会清除）
  static Future<File> get _primaryFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupFilename');
  }

  /// 通过 Android 方法通道写入 Download/wordbank/（MediaStore，无需权限）
  static Future<void> _writeToSharedStorage(String data) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('writeToSharedStorage', {
        'fileName': _backupFilename,
        'content': data,
      });
    } catch (_) {
      // 方法通道不可用时静默失败
    }
  }

  /// 通过 Android 方法通道从 Download/wordbank/ 读取
  static Future<String?> _readFromSharedStorage() async {
    if (kIsWeb) return null;
    try {
      final result = await _channel.invokeMethod<String>('readFromSharedStorage', {
        'fileName': _backupFilename,
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveToFiles(String data) async {
    // 写到应用文档目录
    try {
      final primary = await _primaryFile;
      await primary.writeAsString(data, flush: true);
    } catch (_) {}

    // 通过 MediaStore 写到公共 Downloads 目录（卸载重装后依然存在）
    await _writeToSharedStorage(data);
  }

  static Future<String?> _loadFromFiles() async {
    // 先试应用文档目录
    try {
      final primary = await _primaryFile;
      if (await primary.exists()) {
        return await primary.readAsString();
      }
    } catch (_) {}

    // 再试公共 Downloads 目录（通过 MediaStore）
    try {
      final data = await _readFromSharedStorage();
      if (data != null && data.isNotEmpty) {
        // 读到后写回应用文档目录
        try {
          final primary = await _primaryFile;
          await primary.writeAsString(data, flush: true);
        } catch (_) {}
        return data;
      }
    } catch (_) {}

    return null;
  }

  // --- Imported words (file-based, survives reinstall) ---

  static Future<List<WordPair>> loadImportedWords() async {
    // 先从文件加载
    final fileData = await _loadFromFiles();
    if (fileData != null && fileData.isNotEmpty) {
      final words = _decodeWordList(fileData);
      if (words.isNotEmpty) {
        // 同步到 SharedPreferences 作为缓存
        try {
          final prefs = await _prefs;
          await prefs.setString(_importedWordsKey, fileData);
        } catch (_) {}
        return words;
      }
    }

    // 文件不存在，尝试 SharedPreferences 旧数据
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_importedWordsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final words = _decodeWordList(jsonStr);
    if (words.isNotEmpty) {
      // 迁移到文件存储
      await _saveToFiles(jsonStr);
    }
    return words;
  }

  static Future<void> saveImportedWords(List<WordPair> words) async {
    final jsonStr = _encodeWordList(words);

    // 保存到文件（持久化）
    await _saveToFiles(jsonStr);

    // 同步到 SharedPreferences（快速缓存）
    final prefs = await _prefs;
    await prefs.setString(_importedWordsKey, jsonStr);
    await prefs.setInt(_totalImportedKey, words.length);
  }

  static Future<void> deleteImportedWord(String id) async {
    final words = await loadImportedWords();
    words.removeWhere((w) => w.id == id);
    await saveImportedWords(words);
  }

  static Future<int> getImportedCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_totalImportedKey) ?? 0;
  }

  // --- Wrong words ---

  static Future<List<WordPair>> loadWrongWords() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_wrongWordsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    return _decodeWordList(jsonStr);
  }

  static Future<void> saveWrongWords(List<WordPair> words) async {
    final prefs = await _prefs;
    final unique = <String, WordPair>{};
    for (final w in words) {
      unique[w.id] = w;
    }
    final capped = unique.values.take(200).toList();
    await prefs.setString(_wrongWordsKey, _encodeWordList(capped));
  }

  static Future<void> addWrongWords(List<WordPair> newWrong) async {
    final existing = await loadWrongWords();
    final all = [...existing, ...newWrong];
    await saveWrongWords(all);
  }

  static Future<void> removeWrongWord(String id) async {
    final words = await loadWrongWords();
    words.removeWhere((w) => w.id == id);
    await saveWrongWords(words);
  }

  static Future<void> clearWrongWords() async {
    final prefs = await _prefs;
    await prefs.remove(_wrongWordsKey);
  }

  // --- Last result ---

  static Future<SessionResult?> loadLastResult() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_lastResultKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SessionResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastResult(SessionResult result) async {
    final prefs = await _prefs;
    await prefs.setString(_lastResultKey, jsonEncode(result.toJson()));
  }

  // --- Word stats (Ebbinghaus forgetting curve) ---

  static Future<Map<String, WordStats>> loadWordStats() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_wordStatsKey);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) =>
          MapEntry(k, WordStats.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveWordStats(Map<String, WordStats> stats) async {
    final prefs = await _prefs;
    final map = stats.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_wordStatsKey, jsonEncode(map));
  }

  // --- Manual export/import (survives uninstall) ---

  /// 导出词库到 Download/wordbank/（通过 MediaStore，卸载重装后仍可恢复）
  static Future<bool> exportToDownloads() async {
    final words = await loadImportedWords();
    if (words.isEmpty) return false;

    final jsonStr = _encodeWordList(words);
    await _saveToFiles(jsonStr);

    // 同时写一个带时间戳的备份文件，方便用户手动管理
    try {
      final now = DateTime.now();
      final ts =
          '${now.year}${_pad2(now.month)}${_pad2(now.day)}_${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}';
      await _channel.invokeMethod('writeToSharedStorage', {
        'fileName': 'wordbank_backup_$ts.json',
        'content': jsonStr,
      });
    } catch (_) {}

    return true;
  }

  /// 从文件路径导入词库 JSON（用于 file_picker 手动导入）
  static Future<int> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 0;
      final content = await file.readAsString();
      final words = _decodeWordList(content);
      if (words.isEmpty) return 0;
      await saveImportedWords(words);
      return words.length;
    } catch (_) {
      return 0;
    }
  }

  /// 从 Download/wordbank/ 恢复备份词库（通过 MediaStore）
  static Future<int> restoreFromDownloads() async {
    final fileData = await _loadFromFiles();
    if (fileData == null || fileData.isEmpty) return 0;
    final words = _decodeWordList(fileData);
    if (words.isEmpty) return 0;
    await saveImportedWords(words);
    return words.length;
  }

  /// 从 JSON 字符串恢复词库（用于 file_picker 手动选择文件后解析）
  static Future<int> restoreFromJsonString(String jsonStr) async {
    final words = _decodeWordList(jsonStr);
    if (words.isEmpty) return 0;
    await saveImportedWords(words);
    return words.length;
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  // --- Helpers ---

  static String _encodeWordList(List<WordPair> words) =>
      jsonEncode(words.map((w) => w.toJson()).toList());

  static List<WordPair> _decodeWordList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => WordPair.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}