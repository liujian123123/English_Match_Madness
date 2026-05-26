import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../game/scoring.dart';
import '../game/word_pool.dart';
import '../models/game_config.dart';
import '../models/word_pair.dart';
import '../models/word_stats.dart';
import '../models/session_result.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../widgets/match_card.dart';
import '../widgets/timer_widget.dart';
import '../widgets/score_display.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  final WordPool wordPool;

  const GameScreen({
    super.key,
    required this.config,
    required this.wordPool,
  });

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  final SoundService _sound = SoundService();

  // Word pool management
  static const int _visibleCount = 4;
  static const int _batchSize = 100;
  List<WordPair> _currentPairs = [];
  List<WordPair> _wordQueue = [];
  Map<String, WordStats> _wordStats = {};

  // Column arrangement
  List<int> _leftIndices = [];
  List<int> _rightIndices = [];

  // Game state
  final Set<String> _matchedIds = {};
  int? _selectedLeftIndex;
  int? _selectedRightIndex;
  int _correctMatches = 0;
  int _wrongAttempts = 0;
  int _score = 0;
  bool _isAnimating = false;
  final Set<String> _wrongWordIds = {};
  final _timerKey = GlobalKey<TimerWidgetState>();

  @override
  void initState() {
    super.initState();
    _initGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timerKey.currentState?.start();
    });
  }

  void _initGame() async {
    final allWords = widget.wordPool.allWords;
    if (allWords.isEmpty) return;

    // Load stats and select words by Ebbinghaus priority
    _wordStats = await StorageService.loadWordStats();
    final prioritized = await widget.wordPool.selectByPriority(_batchSize);
    if (prioritized.isEmpty) return;

    _wordQueue = List.from(prioritized);
    _currentPairs = _wordQueue.sublist(0, _visibleCount.clamp(0, _wordQueue.length));
    _wordQueue.removeRange(0, _currentPairs.length);

    _shuffleColumns();
    if (mounted) setState(() {});
  }

  void _shuffleColumns() {
    final random = Random();
    _leftIndices = List.generate(_currentPairs.length, (i) => i)..shuffle(random);
    _rightIndices = List.generate(_currentPairs.length, (i) => i)..shuffle(random);
  }

  void _onCardTap(bool isLeft, int index) {
    if (_isAnimating) return;

    final pairIndex = isLeft ? _leftIndices[index] : _rightIndices[index];
    final wordPair = _currentPairs[pairIndex];
    if (_matchedIds.contains(wordPair.id)) return;

    // Audio mode: play TTS on any card tap
    if (widget.config.isAudioMode) {
      _sound.speakEnglish(wordPair.word);
    }

    if (_selectedLeftIndex == null && _selectedRightIndex == null) {
      // First selection
      if (isLeft) {
        _selectedLeftIndex = index;
      } else {
        _selectedRightIndex = index;
      }
      setState(() {});
      return;
    }

    // One side already selected
    if (isLeft) {
      if (_selectedLeftIndex == index) {
        // Deselect
        _selectedLeftIndex = null;
        setState(() {});
        return;
      }
      if (_selectedLeftIndex != null) {
        // Replace left selection
        _selectedLeftIndex = index;
        setState(() {});
        return;
      }
      _selectedLeftIndex = index;
    } else {
      if (_selectedRightIndex == index) {
        _selectedRightIndex = null;
        setState(() {});
        return;
      }
      if (_selectedRightIndex != null) {
        _selectedRightIndex = index;
        setState(() {});
        return;
      }
      _selectedRightIndex = index;
    }

    // Check if both sides are selected
    if (_selectedLeftIndex != null && _selectedRightIndex != null) {
      unawaited(_checkMatch());
    }
    setState(() {});
  }

  Future<void> _checkMatch() async {
    final leftPairIndex = _leftIndices[_selectedLeftIndex!];
    final rightPairIndex = _rightIndices[_selectedRightIndex!];
    final leftPair = _currentPairs[leftPairIndex];
    final rightPair = _currentPairs[rightPairIndex];

    // 确保所有音频完全停止后再开始新的播放（避免竞争）
    await _sound.stopAll();
    _isAnimating = true;

    if (leftPair.id == rightPair.id) {
      // 正确匹配：直接播放单词读音（不等待播放结束）
      _sound.speakEnglish(leftPair.word);
      _correctMatches++;
      _matchedIds.add(leftPair.id);

      // Update Ebbinghaus stats: correct → interval grows
      _wordStats.putIfAbsent(leftPair.id, () => WordStats(wordId: leftPair.id));
      _wordStats[leftPair.id]!.recordCorrect();

      _score = calculateScore(_correctMatches);

      setState(() {});

      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _selectedLeftIndex = null;
        _selectedRightIndex = null;

        // Replace matched pair with new one from queue
        if (_wordQueue.isNotEmpty) {
          final matchedIndex = leftPairIndex;
          _currentPairs[matchedIndex] = _wordQueue.removeAt(0);
          _matchedIds.remove(leftPair.id);
        }

        _isAnimating = false;
        setState(() {});
      });
    } else {
      // 错误匹配：只播放失败音效（不等待播放结束），无 TTS
      _sound.playFailure();
      _wrongAttempts++;
      _wrongWordIds.add(leftPair.id);
      _wrongWordIds.add(rightPair.id);

      // Update Ebbinghaus stats: wrong → interval resets for both involved words
      for (final id in [leftPair.id, rightPair.id]) {
        _wordStats.putIfAbsent(id, () => WordStats(wordId: id));
        _wordStats[id]!.recordWrong();
      }

      setState(() {});

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _selectedLeftIndex = null;
        _selectedRightIndex = null;
        _isAnimating = false;
        setState(() {});
      });
    }
  }

  void _completeGame() {
    _isAnimating = true;
    _timerKey.currentState?.stop();

    final allPairs = widget.wordPool.allWords;
    final wrongWords = allPairs
        .where((p) => _wrongWordIds.contains(p.id))
        .toList();

    final result = SessionResult(
      timestamp: DateTime.now(),
      score: _score,
      correctMatches: _correctMatches,
      wrongAttempts: _wrongAttempts,
      totalPairsTried: _correctMatches + _wrongAttempts,
      timeUsedSeconds: _timerKey.currentState!.elapsed,
      timeLimitSeconds: widget.config.timeLimitSeconds,
      wrongWords: wrongWords,
    );

    StorageService.saveLastResult(result);
    StorageService.addWrongWords(wrongWords);
    StorageService.saveWordStats(_wordStats);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result),
      ),
    );
  }

  void _onTimeout() {
    _completeGame();
  }

  bool _isCardWrong(bool isLeft, int index) {
    if (!_isAnimating) return false;
    if (_selectedLeftIndex == null || _selectedRightIndex == null) return false;

    final pairIndex = isLeft ? _leftIndices[index] : _rightIndices[index];
    final pair = _currentPairs[pairIndex];

    final leftPair = _currentPairs[_leftIndices[_selectedLeftIndex!]];
    final rightPair = _currentPairs[_rightIndices[_selectedRightIndex!]];

    if (leftPair.id == rightPair.id) return false; // correct, not wrong

    return (isLeft && _selectedLeftIndex == index) ||
        (!isLeft && _selectedRightIndex == index) ||
        pair.id == leftPair.id ||
        pair.id == rightPair.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.config.difficultyLabel,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
            const SizedBox(width: 8),
            TimerWidget(
              key: _timerKey,
              totalSeconds: widget.config.timeLimitSeconds,
              onTimeout: _onTimeout,
            ),
          ],
        ),
        actions: [
          ScoreDisplay(score: _score),
          const SizedBox(width: 12),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF666666)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildColumnHeader(
                      widget.config.isAudioMode ? '听音配对' : '中文释义',
                      widget.config.isAudioMode ? const Color(0xFF9C27B0) : const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _currentPairs.length,
                        itemBuilder: (_, i) {
                          final pairIdx = _leftIndices[i];
                          final pair = _currentPairs[pairIdx];
                          return MatchCard(
                            text: widget.config.isAudioMode ? '......' : pair.translation,
                            isSelected: _selectedLeftIndex == i,
                            isMatched: _matchedIds.contains(pair.id),
                            isWrong: _isCardWrong(true, i),
                            isLeft: true,
                            onTap: () => _onCardTap(true, i),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildColumnHeader(
                      widget.config.isAudioMode ? '中文释义' : 'English',
                      widget.config.isAudioMode ? const Color(0xFF2196F3) : const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _currentPairs.length,
                        itemBuilder: (_, i) {
                          final pairIdx = _rightIndices[i];
                          final pair = _currentPairs[pairIdx];
                          return MatchCard(
                            text: pair.translation,
                            isSelected: _selectedRightIndex == i,
                            isMatched: _matchedIds.contains(pair.id),
                            isWrong: _isCardWrong(false, i),
                            isLeft: false,
                            onTap: () => _onCardTap(false, i),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}