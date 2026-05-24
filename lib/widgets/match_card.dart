import 'package:flutter/material.dart';

class MatchCard extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isMatched;
  final bool isWrong;
  final bool isLeft;
  final VoidCallback onTap;

  const MatchCard({
    super.key,
    required this.text,
    required this.isSelected,
    required this.isMatched,
    required this.isWrong,
    required this.isLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isMatched) {
      bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      borderColor = const Color(0xFF4CAF50);
      textColor = const Color(0xFF4CAF50);
    } else if (isWrong) {
      bgColor = const Color(0xFFE53935).withValues(alpha: 0.1);
      borderColor = const Color(0xFFE53935);
      textColor = const Color(0xFFE53935);
    } else if (isSelected) {
      bgColor = const Color(0xFF2196F3).withValues(alpha: 0.12);
      borderColor = const Color(0xFF2196F3);
      textColor = const Color(0xFF1565C0);
    } else {
      bgColor = Colors.white;
      borderColor = const Color(0xFFE0E0E0);
      textColor = const Color(0xFF333333);
    }

    return AnimatedScale(
      scale: isMatched ? 0.85 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        opacity: isMatched ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: isMatched ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1.5),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                if (!isSelected && !isMatched)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLeft ? 18 : 19,
                  fontWeight:
                      isSelected || isLeft ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}