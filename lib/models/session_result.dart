import 'word_pair.dart';

class SessionResult {
  final DateTime timestamp;
  final int score;
  final int correctMatches;
  final int wrongAttempts;
  final int totalPairsTried;
  final int timeUsedSeconds;
  final int timeLimitSeconds;
  final List<WordPair> wrongWords;

  const SessionResult({
    required this.timestamp,
    required this.score,
    required this.correctMatches,
    required this.wrongAttempts,
    required this.totalPairsTried,
    required this.timeUsedSeconds,
    required this.timeLimitSeconds,
    required this.wrongWords,
  });

  double get accuracy {
    final total = correctMatches + wrongAttempts;
    if (total == 0) return 1.0;
    return correctMatches / total;
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'score': score,
        'correctMatches': correctMatches,
        'wrongAttempts': wrongAttempts,
        'totalPairsTried': totalPairsTried,
        'timeUsedSeconds': timeUsedSeconds,
        'timeLimitSeconds': timeLimitSeconds,
        'wrongWords': wrongWords.map((w) => w.toJson()).toList(),
      };

  factory SessionResult.fromJson(Map<String, dynamic> json) => SessionResult(
        timestamp: DateTime.parse(json['timestamp'] as String),
        score: json['score'] as int,
        correctMatches: json['correctMatches'] as int,
        wrongAttempts: json['wrongAttempts'] as int,
        totalPairsTried: json['totalPairsTried'] as int? ??
            json['correctMatches'] as int,
        timeUsedSeconds: json['timeUsedSeconds'] as int,
        timeLimitSeconds:
            json['timeLimitSeconds'] as int? ?? json['pairCount'] as int? ?? 60,
        wrongWords: (json['wrongWords'] as List)
            .map((e) => WordPair.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}