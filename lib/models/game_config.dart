class GameConfig {
  final int timeLimitSeconds;
  final bool isAudioMode;

  const GameConfig({
    required this.timeLimitSeconds,
    this.isAudioMode = false,
  });

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

  String get modeLabel => isAudioMode ? '听音配对' : '文字配对';
}