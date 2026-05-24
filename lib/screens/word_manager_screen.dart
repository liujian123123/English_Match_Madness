import 'dart:async';
import 'package:flutter/material.dart';
import '../models/word_pair.dart';
import '../services/storage_service.dart';

class WordManagerScreen extends StatefulWidget {
  const WordManagerScreen({super.key});

  @override
  State<WordManagerScreen> createState() => _WordManagerScreenState();
}

class _WordManagerScreenState extends State<WordManagerScreen> {
  List<WordPair> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final words = await StorageService.loadImportedWords();
    if (!mounted) return;
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  Future<void> _deleteWord(WordPair word) async {
    await StorageService.deleteImportedWord(word.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 "${word.word}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final wordCtrl = TextEditingController();
    final transCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加单词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wordCtrl,
              decoration: const InputDecoration(
                labelText: '英文单词',
                hintText: 'apple',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: transCtrl,
              decoration: const InputDecoration(
                labelText: '中文释义',
                hintText: '苹果',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (wordCtrl.text.trim().isEmpty ||
                  transCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请填写英文单词和中文释义')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final word = wordCtrl.text.trim().toLowerCase();
    final translation = transCtrl.text.trim();

    final existing = await StorageService.loadImportedWords();
    final newPair = WordPair(
      id: '${word}_$translation',
      word: word,
      translation: translation,
    );

    // Check if already exists
    if (existing.any((w) => w.id == newPair.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该单词已存在')),
      );
      return;
    }

    existing.add(newPair);
    await StorageService.saveImportedWords(existing);
    await _load();
  }

  Future<void> _showEditDialog(WordPair word) async {
    final transCtrl = TextEditingController(text: word.translation);
    final noteCtrl = TextEditingController(text: word.note ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          word.word,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: transCtrl,
              decoration: const InputDecoration(
                labelText: '中文释义',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '详细注释（可选）',
                hintText: '例句、用法说明等',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (transCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请填写中文释义')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    final translation = transCtrl.text.trim();
    final note = noteCtrl.text.trim();

    final words = await StorageService.loadImportedWords();
    final idx = words.indexWhere((w) => w.id == word.id);
    if (idx == -1) return;

    // 如果释义变了，需要更新 id
    final newId = note.isNotEmpty ? '${word.word}_${translation}_$note' : '${word.word}_$translation';
    words[idx] = WordPair(
      id: newId,
      word: word.word,
      translation: translation,
      note: note.isNotEmpty ? note : null,
    );
    await StorageService.saveImportedWords(words);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '词库管理',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmptyState()
              : _buildWordList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('添加单词'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Color(0xFFDDDDDD)),
          SizedBox(height: 16),
          Text(
            '暂无导入的单词',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          SizedBox(height: 8),
          Text(
            '通过粘贴导入或 JSON 导入添加单词',
            style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _words.length,
      itemBuilder: (_, i) {
        final word = _words[i];
        return Dismissible(
          key: ValueKey(word.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除确认'),
                content: Text('确定要删除 "${word.word}" 吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => _deleteWord(word),
          child: GestureDetector(
            onTap: () => _showEditDialog(word),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          word.translation,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFCCCCCC)),
                    ],
                  ),
                  if (word.note != null && word.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        word.note!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}