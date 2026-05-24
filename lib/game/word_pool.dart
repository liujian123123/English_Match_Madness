import 'dart:math';
import '../models/word_pair.dart';
import '../models/word_stats.dart';
import '../services/storage_service.dart';

class WordPool {
  List<WordPair> _importedWords = [];
  bool _initialized = false;

  List<WordPair> get allWords => _importedWords;

  Future<void> init() async {
    if (_initialized) return;
    await _loadImportedWords();
    _initialized = true;
  }

  Future<void> _loadImportedWords() async {
    _importedWords = await StorageService.loadImportedWords();
  }

  /// Select words prioritized by Ebbinghaus forgetting curve.
  /// New/unseen words rank highest; well-practiced words rank lowest.
  /// Words the user recently got wrong get a boost.
  Future<List<WordPair>> selectByPriority(int count) async {
    if (_importedWords.isEmpty) return [];
    if (_importedWords.length <= count) return List.from(_importedWords);

    final stats = await StorageService.loadWordStats();
    final random = Random();

    // Sort by priority (descending), add a small random jitter (±5) to avoid ties
    final sorted = List<WordPair>.from(_importedWords)..sort((a, b) {
      final pa = _effectivePriority(a.id, stats) + random.nextDouble() * 5;
      final pb = _effectivePriority(b.id, stats) + random.nextDouble() * 5;
      return pb.compareTo(pa);
    });

    return sorted.take(count).toList();
  }

  Future<void> addImportedWords(List<WordPair> words) async {
    final existingIds = <String>{};
    for (final w in _importedWords) {
      existingIds.add(w.id);
    }

    for (final w in words) {
      if (!existingIds.contains(w.id)) {
        _importedWords.add(w);
        existingIds.add(w.id);
      }
    }

    await StorageService.saveImportedWords(_importedWords);
  }

  double _effectivePriority(String wordId, Map<String, WordStats> stats) {
    final s = stats[wordId];
    if (s == null) return 100.0; // new word — highest priority
    return s.priority;
  }
}