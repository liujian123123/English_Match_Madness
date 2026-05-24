import 'package:flutter/material.dart';
import '../models/word_pair.dart';
import '../services/storage_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<WordPair> _wrongWords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final words = await StorageService.loadWrongWords();
    if (!mounted) return;
    setState(() {
      _wrongWords = words;
      _loading = false;
    });
  }

  Future<void> _removeWord(String id) async {
    await StorageService.removeWrongWord(id);
    setState(() {
      _wrongWords.removeWhere((w) => w.id == id);
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空错题'),
        content: const Text('确定清空所有错题记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.clearWrongWords();
      setState(() => _wrongWords = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '错题复习',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_wrongWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Color(0xFF999999)),
              onPressed: _clearAll,
              tooltip: '清空全部',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wrongWords.isEmpty
              ? _buildEmptyState()
              : _buildWordList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Color(0xFFE0E0E0),
          ),
          SizedBox(height: 16),
          Text(
            '暂无错题',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '继续保持！',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFBBBBBB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _wrongWords.length,
      itemBuilder: (_, i) {
        final word = _wrongWords[i];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFFE53935),
                size: 18,
              ),
            ),
            title: Text(
              word.word,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
            subtitle: Text(
              word.translation,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 14,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline,
                  color: Color(0xFFBDBDBD), size: 22),
              onPressed: () => _removeWord(word.id),
              tooltip: '移出错题本',
            ),
          ),
        );
      },
    );
  }
}