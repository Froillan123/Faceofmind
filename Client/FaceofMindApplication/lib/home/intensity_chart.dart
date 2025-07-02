import 'package:flutter/material.dart';

class IntensityChart extends StatelessWidget {
  final List<dynamic> data;
  const IntensityChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.map((e) => e['day'] as String).toList();
    final intensities = data.map((e) => e['intensity_tally'] as Map<String, dynamic>).toList();
    final colors = {
      'mild': Colors.green[300]!,
      'moderate': Colors.orange[300]!,
      'severe': Colors.red[300]!,
    };
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Intensity Chart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(days.length, (i) {
                  final mild = intensities[i]['mild'] ?? 0;
                  final moderate = intensities[i]['moderate'] ?? 0;
                  final severe = intensities[i]['severe'] ?? 0;
                  final total = mild + moderate + severe;
                  double maxBar = 80;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height: total > 0 ? maxBar : 20,
                              width: 18,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: total > 0 ? (severe / (total == 0 ? 1 : total)) * maxBar : 0,
                                  width: 18,
                                  decoration: BoxDecoration(
                                    color: colors['severe'],
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                  ),
                                ),
                                Container(
                                  height: total > 0 ? (moderate / (total == 0 ? 1 : total)) * maxBar : 0,
                                  width: 18,
                                  color: colors['moderate'],
                                ),
                                Container(
                                  height: total > 0 ? (mild / (total == 0 ? 1 : total)) * maxBar : 0,
                                  width: 18,
                                  decoration: BoxDecoration(
                                    color: colors['mild'],
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_shortDay(days[i]), style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legend('Mild', colors['mild']!),
                _legend('Moderate', colors['moderate']!),
                _legend('Severe', colors['severe']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDay(String day) {
    try {
      final date = DateTime.parse(day);
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    } catch (_) {
      return day;
    }
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
} 