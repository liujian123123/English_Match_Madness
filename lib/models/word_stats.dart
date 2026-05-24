class WordStats {
  final String wordId;
  int correctCount;
  int wrongCount;
  DateTime lastSeen;
  int intervalSeconds;

  WordStats({
    required this.wordId,
    this.correctCount = 0,
    this.wrongCount = 0,
    DateTime? lastSeen,
    this.intervalSeconds = 30,
  }) : lastSeen = lastSeen ?? DateTime(2000);

  /// Ebbinghaus forgetting curve priority (0-100).
  /// Higher = more likely to appear.
  double get priority {
    if (correctCount == 0 && wrongCount == 0) return 100.0; // never seen
    final elapsed = DateTime.now().difference(lastSeen).inSeconds;
    if (intervalSeconds <= 0) return 100.0;
    final overdue = elapsed / intervalSeconds;
    return (overdue * 100).clamp(0, 100);
  }

  void recordCorrect() {
    correctCount++;
    lastSeen = DateTime.now();
    // Interval doubles with each correct recall: 30s → 60s → 120s → 240s → 480s → 960s
    intervalSeconds = (intervalSeconds * 2).clamp(30, 86400);
  }

  void recordWrong() {
    wrongCount++;
    lastSeen = DateTime.now();
    // Reset interval on wrong answer — word needs frequent review again
    intervalSeconds = 30;
  }

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'lastSeen': lastSeen.toIso8601String(),
        'intervalSeconds': intervalSeconds,
      };

  factory WordStats.fromJson(Map<String, dynamic> json) => WordStats(
        wordId: json['wordId'] as String,
        correctCount: json['correctCount'] as int? ?? 0,
        wrongCount: json['wrongCount'] as int? ?? 0,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : DateTime(2000),
        intervalSeconds: json['intervalSeconds'] as int? ?? 30,
      );
}