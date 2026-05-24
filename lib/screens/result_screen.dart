import 'package:flutter/material.dart';
import '../models/session_result.dart';

class ResultScreen extends StatelessWidget {
  final SessionResult result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = result.timeUsedSeconds ~/ 60;
    final seconds = result.timeUsedSeconds % 60;
    final timeStr = '$minutes分$seconds秒';
    final accuracyPercent = (result.accuracy * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '本轮结果',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF666666)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildScoreCircle(context),
              const SizedBox(height: 24),
              _buildStatsCard(context, timeStr, accuracyPercent),
              const SizedBox(height: 24),
              if (result.wrongWords.isNotEmpty) _buildWrongWordsSection(context),
              const SizedBox(height: 32),
              _buildActionButtons(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle(BuildContext context) {
    return Column(
      children: [
        Text(
          '${result.correctMatches}',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6D00),
          ),
        ),
        const Text(
          '配对成功',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF999999),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, String timeStr, int accuracy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatRow(Icons.timer_outlined, '用时', timeStr),
          const Divider(height: 24),
          _buildStatRow(Icons.score_outlined, '得分', '${result.score}'),
          const Divider(height: 24),
          _buildStatRow(Icons.cancel_outlined, '错误次数', '${result.wrongAttempts}'),
          const Divider(height: 24),
          _buildStatRow(Icons.pie_chart_outline, '正确率', '$accuracy%'),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF999999)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildWrongWordsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text(
                '答错的单词',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result.wrongWords.map((w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        w.word,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    Text(
                      w.translation,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _playAgain(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              '再来一局',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text(
              '返回主页',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF999999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _playAgain(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}