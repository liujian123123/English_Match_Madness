import 'dart:async';
import 'package:flutter/material.dart';

class TimerWidget extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onTimeout;

  const TimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onTimeout,
  });

  @override
  State<TimerWidget> createState() => TimerWidgetState();
}

class TimerWidgetState extends State<TimerWidget> {
  int _remaining = 0;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        _timer?.cancel();
        _isRunning = false;
        widget.onTimeout();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  int get elapsed => widget.totalSeconds - _remaining;
  int get remaining => _remaining;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLow = _remaining <= 10;
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLow ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: isLow ? const Color(0xFFE53935) : const Color(0xFF666666),
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isLow ? const Color(0xFFE53935) : const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}