import 'package:flutter/material.dart';

class DominantEmotionChart extends StatelessWidget {
  final List<dynamic> data;
  final Map<String, Color> emotionColors;
  const DominantEmotionChart({super.key, required this.data, required this.emotionColors});

  @override
  Widget build(BuildContext context) {
    // Prepare data for chart
    final days = data.map((e) => e['day'] as String).toList();
    final emotions = data.map((e) => e['dominant_emotion'] as String?).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Dominant Emotions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const Spacer(),
                // Add week range or filter here if needed
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(days.length, (i) {
                    final emotion = emotions[i];
                    final color = emotionColors[emotion ?? 'neutral'] ?? Colors.grey.shade300;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: emotion != null ? 80 : 20,
                            width: 24,
                            decoration: BoxDecoration(
                              color: color.withOpacity(emotion != null ? 0.8 : 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: emotion != null
                                  ? Icon(_emotionIcon(emotion), color: Colors.white, size: 20)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_shortDay(days[i]), style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emotionColors.entries.map((e) => _legend(e.key, e.value)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDay(String day) {
    // Expects day as yyyy-mm-dd, returns Mon, Tue, etc.
    try {
      final date = DateTime.parse(day);
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    } catch (_) {
      return day;
    }
  }

  IconData _emotionIcon(String? emotion) {
    switch (emotion) {
      case 'happy':
        return Icons.sentiment_satisfied_alt;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Widget _legend(String emotion, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(_capitalize(emotion), style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
} 