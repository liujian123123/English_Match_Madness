import 'package:flutter/material.dart';
import '../game/word_pool.dart';
import '../models/dictionary_result.dart';
import '../models/word_pair.dart';
import '../services/dictionary_service.dart';

class PasteImportScreen extends StatefulWidget {
  const PasteImportScreen({super.key});

  @override
  State<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends State<PasteImportScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<_WordResult> _results = [];
  String? _error;

  // 用户自定义的释义和注释（编辑后覆盖 API 结果）
  final _customTranslations = <String, String>{};
  final _customNotes = <String, String>{};

  Future<void> _lookup() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请先粘贴单词列表');
      return;
    }

    final words = raw
        .split(RegExp(r'[\n,，\s]+'))
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty && RegExp(r'^[a-zA-Z]+$').hasMatch(w))
        .toSet()
        .toList();

    if (words.isEmpty) {
      setState(() => _error = '未识别到有效的英文单词');
      return;
    }

    if (words.length > 50) {
      setState(() => _error = '一次最多导入 50 个单词');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = words.map((w) => _WordResult(word: w)).toList();
    });

    for (int i = 0; i < _results.length; i++) {
      final result = await DictionaryService.lookup(_results[i].word);
      if (!mounted) return;
      setState(() {
        _results[i].result = result;
        _results[i].done = true;
      });
      // 避免请求过快触发限流
      if (i < _results.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _import() async {
    final selected =
        _results.where((r) => r.result != null && r.result!.isSuccess && r.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要导入的单词')),
      );
      return;
    }

    final wordPool = WordPool();
    await wordPool.init();
    await wordPool.addImportedWords(
      selected.map((r) {
        final translation = _customTranslations[r.word] ?? r.result!.translation;
        final note = _customNotes[r.word];
        return WordPair(
          id: note != null ? '${r.word}_${translation}_$note' : '${r.word}_$translation',
          word: r.word,
          translation: translation,
          note: note,
        );
      }).toList(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功导入 ${selected.length} 个单词'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '粘贴导入单词',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputSection(),
                    if (_error != null) _buildError(),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildResultsSection(),
                    ],
                  ],
                ),
              ),
            ),
            if (_results.isNotEmpty && !_loading) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Row(
              children: [
                Icon(Icons.paste, size: 18, color: Color(0xFF666666)),
                SizedBox(width: 8),
                Text(
                  '粘贴英文单词',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              maxLines: 8,
              minLines: 5,
              decoration: InputDecoration(
                hintText: '每行一个单词，例如：\nhello\nworld\napple\nbook',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14, height: 1.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2196F3)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search, size: 20),
                label: Text(_loading ? '正在查询...' : '查询释义'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(_WordResult r) async {
    final transCtrl = TextEditingController(
      text: _customTranslations[r.word] ?? r.result!.translation,
    );
    final noteCtrl = TextEditingController(
      text: _customNotes[r.word] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          r.word,
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
                  const SnackBar(content: Text('请输入中文释义')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() {
      final trans = transCtrl.text.trim();
      final note = noteCtrl.text.trim();
      if (trans != r.result!.translation) {
        _customTranslations[r.word] = trans;
      }
      if (note.isNotEmpty) {
        _customNotes[r.word] = note;
      } else {
        _customNotes.remove(r.word);
      }
    });
  }

  bool _isSuccess(_WordResult r) => r.result?.isSuccess ?? false;

  Widget _buildResultsSection() {
    final selectedCount = _results.where((r) => r.selected && _isSuccess(r)).length;
    final doneCount = _results.where((r) => r.done).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.list, size: 18, color: Color(0xFF666666)),
                const SizedBox(width: 8),
                Text(
                  '查询结果（$doneCount/${_results.length}）',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final allSelected = _results.every((r) => r.selected || !_isSuccess(r));
                    for (final r in _results) {
                      if (_isSuccess(r)) r.selected = !allSelected;
                    }
                    setState(() {});
                  },
                  child: Text(
                    selectedCount == _results.where((r) => _isSuccess(r)).length ? '取消全选' : '全选',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._results.map((r) => _buildResultItem(r)),
        ],
      ),
    );
  }

  Widget _buildResultItem(_WordResult r) {
    final isSuccess = _isSuccess(r);
    final customTrans = _customTranslations[r.word];
    final customNote = _customNotes[r.word];
    final displayTrans = customTrans ?? (r.done ? r.result!.translation : '');
    final isCustom = customTrans != null;

    return CheckboxListTile(
      value: r.selected && isSuccess,
      onChanged: isSuccess
          ? (v) => setState(() => r.selected = v ?? false)
          : null,
      title: Text(
        r.word,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF333333),
        ),
      ),
      subtitle: r.done
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isCustom ? '自定义: $displayTrans' : displayTrans,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          color: isCustom
                              ? const Color(0xFF2196F3)
                              : const Color(0xFF666666),
                        ),
                      ),
                    ),
                    if (isSuccess)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFBBBBBB)),
                        onPressed: () => _showEditDialog(r),
                      ),
                  ],
                ),
                if (customNote != null && customNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      customNote,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            )
          : const Text(
              '查询中...',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
      dense: true,
      activeColor: const Color(0xFF2196F3),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildBottomBar() {
    final selectedCount = _results.where((r) => r.selected && _isSuccess(r)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: selectedCount > 0 ? _import : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE0E0E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            '导入 $selectedCount 个单词',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _WordResult {
  final String word;
  DictionaryResult? result;
  bool done;
  bool selected;

  _WordResult({required this.word})
      : done = false,
        selected = true;
}