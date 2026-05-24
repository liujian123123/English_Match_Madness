import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../game/word_pool.dart';
import '../models/word_pair.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<WordPair> _parsedWords = [];
  bool _loading = false;
  String? _errorMessage;
  String _fileName = '';

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _parsedWords = [];
      _fileName = '';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      _fileName = file.name;

      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        setState(() {
          _errorMessage = '无法读取文件内容';
          _loading = false;
        });
        return;
      }

      _parseAndValidate(content);
    } catch (e) {
      setState(() {
        _errorMessage = '读取文件失败：${e.toString()}';
        _loading = false;
      });
    }
  }

  void _parseAndValidate(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        setState(() {
          _errorMessage = 'JSON 格式错误：需要一个数组，如 [{"word": "hello", "translation": "你好"}]';
          _loading = false;
        });
        return;
      }

      final words = <WordPair>[];
      final errors = <int>[];

      for (int i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) {
          errors.add(i + 1);
          continue;
        }
        final word = item['word'];
        final translation = item['translation'];
        if (word is! String || word.trim().isEmpty ||
            translation is! String || translation.trim().isEmpty) {
          errors.add(i + 1);
          continue;
        }
        words.add(WordPair(
          id: '${word}_$translation',
          word: word.trim(),
          translation: translation.trim(),
        ));
      }

      if (words.isEmpty) {
        setState(() {
          _errorMessage = '未找到有效的单词数据，请确保 JSON 包含 "word" 和 "translation" 字段';
          _loading = false;
        });
        return;
      }

      if (words.length > 1000) {
        setState(() {
          _errorMessage = '单词数量超过上限（1000 个），请减少文件中的词条数';
          _loading = false;
        });
        return;
      }

      setState(() {
        _parsedWords = words;
        _loading = false;
        if (errors.isNotEmpty) {
          _errorMessage = '已跳过 ${errors.length} 行无效数据（第 ${errors.take(3).join(", ")}${errors.length > 3 ? "..." : ""} 行）';
        }
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'JSON 格式无效，请检查文件是否为合法的 JSON 格式';
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    setState(() => _loading = true);

    final wordPool = WordPool();
    await wordPool.init();
    await wordPool.addImportedWords(_parsedWords);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功导入 ${_parsedWords.length} 个单词'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '导入词库',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInstructions(),
              const SizedBox(height: 24),
              _buildFilePickerButton(),
              const SizedBox(height: 16),
              if (_errorMessage != null) _buildErrorCard(),
              if (_parsedWords.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPreviewSection(),
              ],
              const Spacer(),
              if (_parsedWords.isNotEmpty) _buildImportButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1976D2)),
              SizedBox(width: 8),
              Text(
                '文件格式要求',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1976D2),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '选择一个 JSON 文件，格式如下：',
            style: TextStyle(color: Color(0xFF1565C0), fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            '[{"word": "apple", "translation": "苹果"},\n'
            ' {"word": "book", "translation": "书"}]',
            style: TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '最多支持 1000 个单词',
            style: TextStyle(color: Color(0xFF1565C0), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _pickFile,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_open_outlined),
        label: Text(
          _fileName.isNotEmpty ? _fileName : '选择 JSON 文件',
          style: const TextStyle(fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFF2196F3)),
          foregroundColor: const Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFE53935)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final displayCount = _parsedWords.length > 20 ? 20 : _parsedWords.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, size: 18, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                '预览（共 ${_parsedWords.length} 个单词）',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._parsedWords.take(displayCount).map((w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        w.word,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      w.translation,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )),
          if (_parsedWords.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '... 还有 ${_parsedWords.length - 20} 个单词',
                style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _import,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          '导入 ${_parsedWords.length} 个单词',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}