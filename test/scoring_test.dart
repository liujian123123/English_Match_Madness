import 'package:flutter_test/flutter_test.dart';
import 'package:match_madness/game/scoring.dart';

void main() {
  group('calculateScore', () {
    test('score equals correct matches * 100', () {
      expect(calculateScore(0), 0);
      expect(calculateScore(1), 100);
      expect(calculateScore(5), 500);
      expect(calculateScore(10), 1000);
      expect(calculateScore(50), 5000);
    });
  });
}