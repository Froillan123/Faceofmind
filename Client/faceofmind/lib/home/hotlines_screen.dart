import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HotlinesScreen extends StatelessWidget {
  const HotlinesScreen({super.key});

  final List<Map<String, String>> hotlines = const [
    {
      'name': 'MUNCH Crisis Hotline',
      'number': '+1800-1888-1553',
    },
    {
      'name': 'Tawag Paglaum - Centro Bisaya',
      'number': '+0966-467-9626',
    },
    {
      'name': 'In Touch: Crisis Line',
      'number': '+6328-893-7603',
    },
    {
      'name': 'HOPELINE',
      'number': '+02-8804-4673',
    },
    {
      'name': 'Cebu City Mental Wellness Center',
      'number': '+032-415-6144',
    },
    {
      'name': 'Cebu Crisis Intervention Unit',
      'number': '+032-254-4348',
    },
    {
      'name': 'DSWD Region 7 Helpline',
      'number': '+032-254-7112',
    },
  ];

  void _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF22C55E);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: mainColor),
        title: const Text(''),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: mainColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Icon(Icons.call, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mental Health Support',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF232B36),
                    letterSpacing: 0.2,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 2)],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              itemCount: hotlines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final hotline = hotlines[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 6,
                  shadowColor: Colors.black12,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _callNumber(hotline['number']!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hotline['name']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF232B36),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _callNumber(hotline['number']!),
                                  child: Text(
                                    hotline['number']!,
                                    style: const TextStyle(
                                      color: Color(0xFF6C7BFF),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: mainColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: mainColor.withOpacity(0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(Icons.call, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 