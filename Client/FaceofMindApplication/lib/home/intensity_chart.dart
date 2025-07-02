import 'package:flutter/material.dart';

class IntensityChart extends StatefulWidget {
  final List<dynamic> data;
  const IntensityChart({super.key, required this.data});

  @override
  State<IntensityChart> createState() => _IntensityChartState();
}

class _IntensityChartState extends State<IntensityChart> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Highlight the current day on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.data.isNotEmpty) {
        final today = DateTime.now();
        for (int i = 0; i < widget.data.length; i++) {
          final dayStr = widget.data[i]['day'] as String;
          try {
            final dayDate = DateTime.parse(dayStr);
            if (dayDate.year == today.year && dayDate.month == today.month && dayDate.day == today.day) {
              setState(() {
                _selectedIndex = i;
              });
              break;
            }
          } catch (_) {}
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.data.map((e) => e['day'] as String).toList();
    final intensities = widget.data.map((e) => e['intensity_tally'] as Map<String, dynamic>).toList();
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
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _selectedIndex = null;
                });
              },
              child: SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(days.length, (i) {
                    final mild = intensities[i]['mild'] ?? 0;
                    final moderate = intensities[i]['moderate'] ?? 0;
                    final severe = intensities[i]['severe'] ?? 0;
                    final total = mild + moderate + severe;
                    double maxBar = 80;
                    final isSelected = _selectedIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedIndex = i;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: total > 0 ? maxBar : 20,
                                  width: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: Colors.blue.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 2))]
                                        : [],
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
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (_selectedIndex != null) ...[
              const SizedBox(height: 16),
              _buildCountDisplay(intensities[_selectedIndex!]),
            ],
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

  Widget _buildCountDisplay(Map<String, dynamic> tally) {
    final mild = tally['mild'] ?? 0;
    final moderate = tally['moderate'] ?? 0;
    final severe = tally['severe'] ?? 0;
    final total = mild + moderate + severe;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _countBox('Mild', mild, Colors.green[400]!),
          const SizedBox(width: 16),
          _countBox('Moderate', moderate, Colors.orange[400]!),
          const SizedBox(width: 16),
          _countBox('Severe', severe, Colors.red[400]!),
          const SizedBox(width: 16),
          _countBox('Total', total, Colors.blue[400]!),
        ],
      ),
    );
  }

  Widget _countBox(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
} 