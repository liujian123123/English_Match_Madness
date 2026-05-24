import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/dictionary_result.dart';
import '../models/word_pair.dart';

class DictionaryService {
  static List<WordPair>? _builtinWords;

  /// 查内置词库（即时返回）
  static Future<String> lookupBuiltin(String word) async {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return '';

    final builtin = await _loadBuiltin();
    for (final pair in builtin) {
      if (pair.word.toLowerCase() == w) {
        return pair.translation;
      }
    }
    return '';
  }

  /// 先查内置词库，查不到的通过有道词典 API（中国可访问）查询
  static Future<DictionaryResult> lookup(String word) async {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return DictionaryResult.notFound();

    // 1. 查内置词库（即时返回）
    final builtinResult = await lookupBuiltin(w);
    if (builtinResult.isNotEmpty) return DictionaryResult.success(builtinResult);

    // 2. 调有道词典 API（中国可访问，无需 key）
    try {
      final uri = Uri.parse(
          'https://dict.youdao.com/jsonapi_s?doctype=json&q=${Uri.encodeComponent(w)}');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 10), onTimeout: () {
        return http.Response('', 408);
      });
      if (response.statusCode == 408) {
        return DictionaryResult.timeout();
      }
      if (response.statusCode != 200) {
        return DictionaryResult.apiError();
      }

      final json = jsonDecode(response.body);

      // 从 ec (English-Chinese dictionary) 模块提取翻译
      // JSON path: ec.word[0].trs[0].tr[0].l.i[0]
      final ec = json['ec'];
      if (ec is Map) {
        final word = ec['word'] as List?;
        if (word != null && word.isNotEmpty) {
          final trs = word[0]['trs'] as List?;
          if (trs != null && trs.isNotEmpty) {
            final tr = trs[0]['tr'] as List?;
            if (tr != null && tr.isNotEmpty) {
              final l = tr[0]['l'] as Map?;
              if (l != null) {
                final i = l['i'] as List?;
                if (i != null && i.isNotEmpty) {
                  final translation = i[0] as String?;
                  if (translation != null && translation.isNotEmpty) {
                    return DictionaryResult.success(
                        translation.replaceAll(RegExp(r'\s*;\s*'), '；'));
                  }
                }
              }
            }
          }
        }
      }

      // 从 web_trans 取第一条作为备选
      final webTrans = json['web_trans'];
      if (webTrans is Map) {
        final webTransList = webTrans['web-translation'] as List?;
        if (webTransList != null && webTransList.isNotEmpty) {
          final trans = webTransList[0]['trans'] as List?;
          if (trans != null && trans.isNotEmpty) {
            final value = trans[0]['value'] as String?;
            if (value != null && value.isNotEmpty) {
              return DictionaryResult.success(value);
            }
          }
        }
      }

      return DictionaryResult.notFound();
    } on TimeoutException {
      return DictionaryResult.timeout();
    } catch (_) {
      return DictionaryResult.networkError();
    }
  }

  static Future<List<WordPair>> _loadBuiltin() async {
    if (_builtinWords != null) return _builtinWords!;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/default_words.json');
      final list = jsonDecode(jsonStr) as List;
      _builtinWords = list
          .map((e) => WordPair.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _builtinWords = [];
    }
    return _builtinWords!;
  }
}