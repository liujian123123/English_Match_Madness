import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../game/word_pool.dart';
import '../models/game_config.dart';
import '../services/storage_service.dart';
import 'game_screen.dart';
import 'import_screen.dart';
import 'paste_import_screen.dart';
import 'review_screen.dart';
import 'word_manager_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _timeLimit = 60;
  int _importedCount = 0;
  int _wrongWordsCount = 0;
  int _lastScore = 0;
  bool _loading = true;

  final List<int> _timeOptions = [60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final imported = await StorageService.getImportedCount();
    final wrongWords = await StorageService.loadWrongWords();
    final lastResult = await StorageService.loadLastResult();

    if (!mounted) return;
    setState(() {
      _importedCount = imported;
      _wrongWordsCount = wrongWords.length;
      _lastScore = lastResult?.correctMatches ?? 0;
      _loading = false;
    });
  }

  Future<void> _exportWordBank() async {
    final words = await StorageService.loadImportedWords();
    if (words.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('词库为空，无需导出'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
      return;
    }

    final jsonStr = jsonEncode(words.map((w) => w.toJson()).toList());

    // 用 file_picker 保存文件（使用系统保存对话框，不需要任何权限）
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存词库备份',
        fileName: 'wordbank_backup.json',
        bytes: utf8.encode(jsonStr),
      );

      if (savedPath != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('词库已导出到 $savedPath'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        return;
      }
    } catch (_) {
      // file_picker 保存失败，尝试 MediaStore 方式
    }

    // 尝试 MediaStore 方式（在部分国产 ROM 上可能不生效）
    final ok = await StorageService.exportToDownloads();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '词库已导出到 Download/wordbank/' : '导出失败，请截图联系开发者'),
        backgroundColor: ok ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
      ),
    );
  }

  Future<void> _restoreWordBank() async {
    // 1. 尝试申请存储权限 + MediaStore 自动恢复
    final granted = await StorageService.requestStoragePermission();
    if (granted) {
      final count = await StorageService.restoreFromDownloads();
      if (count > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已自动恢复 $count 个单词'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        _loadData();
        return;
      }
    }

    // 2. 权限不够或自动恢复失败，用 file_picker 让用户手动选择备份文件
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请在文件选择器中找到 Download/wordbank/ 目录，选择备份文件'),
        backgroundColor: Color(0xFFFF9800),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法读取文件内容'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
        return;
      }

      final count = await StorageService.restoreFromJsonString(content);
      if (!mounted) return;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已手动恢复 $count 个单词'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件中未找到有效的单词数据，请选择正确的备份文件'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('读取文件失败：$e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Madness',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              '单词疯狂匹配',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDifficultySelector(),
                    const SizedBox(height: 24),
                    _buildPlayButton(),
                    const SizedBox(height: 16),
                    if (_lastScore > 0) _buildLastScoreBanner(),
                    if (_lastScore > 0) const SizedBox(height: 16),
                    _buildSecondaryButtons(),
                    const SizedBox(height: 24),
                    _buildInfoRow(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDifficultySelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            '选择难度',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _timeOptions.map((seconds) {
              final isSelected = _timeLimit == seconds;
              final labels = {60: '简单', 90: '普通', 120: '困难', 180: '挑战'};
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _timeLimit = seconds),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      left: seconds == _timeOptions.first ? 0 : 6,
                      right: seconds == _timeOptions.last ? 0 : 6,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${seconds ~/ 60}:00',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF333333),
                          ),
                        ),
                        Text(
                          labels[seconds] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white70
                                : const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _startGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 28),
            SizedBox(width: 8),
            Text(
              '开始游戏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastScoreBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 20, color: Color(0xFFFF9800)),
          const SizedBox(width: 10),
          const Text(
            '上次配对：',
            style: TextStyle(color: Color(0xFF666666), fontSize: 14),
          ),
          Text(
            '$_lastScore 对',
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButtons() {
    return Column(
      children: [
        _buildMenuButton(
          icon: Icons.paste,
          title: '粘贴导入单词',
          subtitle: '直接粘贴英文，自动查询中文释义',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PasteImportScreen()),
          ).then((_) => _loadData()),
        ),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.file_upload_outlined,
          title: 'JSON 导入词库',
          subtitle: _importedCount > 0
              ? '已导入 $_importedCount 个单词'
              : '从 JSON 文件导入单词',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ImportScreen()),
          ).then((_) => _loadData()),
        ),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.library_books_outlined,
          title: '词库管理',
          subtitle: _importedCount > 0
              ? '查看和编辑 $_importedCount 个导入单词'
              : '管理已导入的单词',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WordManagerScreen()),
          ).then((_) => _loadData()),
        ),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.backup_outlined,
          title: '导出词库备份',
          subtitle: '保存词库到 Download/wordbank/',
          onTap: () => unawaited(_exportWordBank()),
        ),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.restore_outlined,
          title: '恢复词库备份',
          subtitle: '从 Download/wordbank/ 恢复词库',
          onTap: () => unawaited(_restoreWordBank()),
        ),
        const SizedBox(height: 8),
        _buildMenuButton(
          icon: Icons.refresh_outlined,
          title: '错题复习',
          subtitle: _wrongWordsCount > 0
              ? '$_wrongWordsCount 个待复习'
              : '暂无错题',
          onTap: _wrongWordsCount > 0
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewScreen()),
                  ).then((_) => _loadData())
              : null,
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF666666), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: Color(0xFFCCCCCC), size: 22),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildInfoChip(Icons.library_books_outlined,
            '词库: ${_getTotalWords()}'),
        const SizedBox(width: 16),
        _buildInfoChip(Icons.star_outline, '最高: $_lastScore 对'),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFBBBBBB)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
        ),
      ],
    );
  }

  int _getTotalWords() {
    return _importedCount;
  }

  void _startGame() async {
    final wordPool = WordPool();
    await wordPool.init();

    final totalWords = wordPool.allWords.length;
    if (totalWords < 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('词库单词不足，请先导入更多单词')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: GameConfig(timeLimitSeconds: _timeLimit),
          wordPool: wordPool,
        ),
      ),
    ).then((_) => _loadData());
  }
}