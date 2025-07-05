import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final void Function(String action) onActionTap;
  const QuickActions({super.key, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'Donate', 'icon': Icons.card_giftcard, 'color': Colors.purple[300]},
      {'label': 'Community', 'icon': Icons.groups, 'color': Colors.green[300]},
      {'label': 'Talk Now Hotlines', 'icon': Icons.phone, 'color': Colors.green[200]},
      {'label': 'History', 'icon': Icons.show_chart, 'color': Colors.orange[200]},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black12, blurRadius: 2)])),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.7,
          children: actions.map((action) {
            return GestureDetector(
              onTap: () => onActionTap(action['label'] as String),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: action['color'] as Color?,
                        child: Icon(action['icon'] as IconData, color: Colors.white),
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action['label'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
} 