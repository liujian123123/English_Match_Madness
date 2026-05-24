class GameConfig {
  final int timeLimitSeconds;

  const GameConfig({required this.timeLimitSeconds});

  int get visiblePairs => 4;

  String get difficultyLabel {
    switch (timeLimitSeconds) {
      case 60:
        return '简单';
      case 90:
        return '普通';
      case 120:
        return '困难';
      case 180:
        return '挑战';
      default:
        return '';
    }
  }
}