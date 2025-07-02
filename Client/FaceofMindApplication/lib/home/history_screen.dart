import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _sessions = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _token;
  String _search = '';
  final int _limit = 5;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchSessions(reset: true);
  }

  Future<void> _loadTokenAndFetchSessions({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    if (reset) {
      _sessions = [];
      _page = 0;
      _hasMore = true;
    }
    final newSessions = await ApiService.fetchUserSessions(
      _token ?? '',
      skip: _page * _limit,
      limit: _limit,
    );
    setState(() {
      if (reset) _sessions = [];
      _sessions.addAll(newSessions);
      _isLoading = false;
      _hasMore = newSessions.length == _limit;
      if (!reset && newSessions.isEmpty) _hasMore = false;
    });
  }

  void _onSearchChanged(String v) {
    setState(() => _search = v);
    _loadTokenAndFetchSessions(reset: true);
  }

  void _showSessionDetails(BuildContext context, int sessionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  'Viewing history...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final session = await ApiService.fetchSessionHistory(_token ?? '', sessionId);
    if (!mounted) return;
    Navigator.of(context).pop(); // Remove loading dialog
    if (session != null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Center(
          child: FractionallySizedBox(
            widthFactor: 0.95,
            child: SessionHistoryDialog(session: session, sessionId: sessionId),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF5CD581);
    final filteredSessions = _sessions
        .where((s) => _search.isEmpty || (s['dominant_emotion']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false) || (s['suggestion']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false))
        .toList();
    // Group by day
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final todayList = <dynamic>[];
    final yesterdayList = <dynamic>[];
    final otherList = <dynamic>[];
    for (final s in filteredSessions) {
      final dt = DateTime.tryParse(s['start_time'] ?? '') ?? today;
      if (_isSameDay(dt, today)) {
        todayList.add(s);
      } else if (_isSameDay(dt, yesterday)) {
        yesterdayList.add(s);
      } else {
        otherList.add(s);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: mainColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  children: [
                    if (todayList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ...todayList.map((s) => _HistoryCard(
                            session: s,
                            onView: () => _showSessionDetails(context, s['id']),
                          )),
                    ],
                    if (yesterdayList.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ...yesterdayList.map((s) => _HistoryCard(
                            session: s,
                            onView: () => _showSessionDetails(context, s['id']),
                          )),
                    ],
                    if (otherList.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('Earlier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ...otherList.map((s) => _HistoryCard(
                            session: s,
                            onView: () => _showSessionDetails(context, s['id']),
                          )),
                    ],
                    if (_isLoading) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_hasMore && !_isLoading) ...[
                      const SizedBox(height: 18),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _page++);
                            _loadTokenAndFetchSessions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Load More', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic session;
  final VoidCallback onView;
  const _HistoryCard({required this.session, required this.onView});

  String _emojiForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'confused':
        return '😕';
      case 'neutral':
        return '😐';
      case 'stressed':
        return '😫';
      case 'tired':
        return '😴';
      default:
        return '🙂';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emotion = session['dominant_emotion']?.toString().capitalize() ?? 'Unknown';
    final suggestion = session['suggestion'] ?? '';
    final emoji = _emojiForEmotion(session['dominant_emotion'] ?? '');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                suggestion.isNotEmpty ? '$emotion – $suggestion' : emotion,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
          GestureDetector(
            onTap: onView,
            child: Padding(
              padding: const EdgeInsets.only(right: 18.0),
              child: Text('view', style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}

class SessionHistoryDialog extends StatelessWidget {
  final Map<String, dynamic> session;
  final int sessionId;
  const SessionHistoryDialog({super.key, required this.session, required this.sessionId});

  String _emojiForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'confused':
        return '😕';
      case 'neutral':
        return '😐';
      case 'stressed':
        return '😫';
      case 'tired':
        return '😴';
      default:
        return '🙂';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF5CD581);
    final accentColor = const Color(0xFFe3fcec);
    final borderColor = Colors.grey[300]!;
    final emotionDetections = session['emotion_detections'] as List<dynamic>? ?? [];
    final detection = emotionDetections.isNotEmpty ? emotionDetections[0] : null;
    final emotionRaw = detection?['facial_data']?['emotion']?.toString() ?? '';
    final emotion = emotionRaw.capitalize();
    final emoji = _emojiForEmotion(emotionRaw);
    final time = detection != null ? DateFormat('HH:mm').format(DateTime.tryParse(detection['timestamp'] ?? '') ?? DateTime.now()) : '';
    final acknowledgment = detection?['wellness_suggestions']?['acknowledgment'] ?? '';
    final suggestions = detection?['wellness_suggestions']?['suggestions'] as List<dynamic>? ?? [];
    final note = detection?['voice_data']?['content'] ?? '';
    final urls = detection?['wellness_suggestions']?['url'] as List<dynamic>? ?? [];
    return Material(
      color: Colors.black.withOpacity(0.25),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'View History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emotion and time
                        Row(
                          children: [
                            Text('$emoji $emotion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
                            const SizedBox(width: 12),
                            Text(time, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Acknowledgment highlight
                        if (acknowledgment.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: mainColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              acknowledgment,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                          ),
                        // Content in white box
                        if (note.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 15),
                                children: [
                                  const TextSpan(text: 'Content: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: note),
                                ],
                              ),
                            ),
                          ),
                        // Wellness Suggestions
                        if (suggestions.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: mainColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: mainColor.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.tips_and_updates, color: Colors.amber, size: 22),
                                    const SizedBox(width: 8),
                                    Text('Wellness Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainColor)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...suggestions.map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(fontSize: 16)),
                                          Expanded(child: Text(s, style: const TextStyle(fontSize: 15))),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                        // URLS
                        if (urls.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Text('Related Links', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: urls.map<Widget>((u) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () async {
                                  await launchUrl(Uri.parse(u.toString()));
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, size: 18, color: Colors.blueGrey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        u.toString(),
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          decoration: TextDecoration.underline,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Scroll cue
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.swipe, color: Colors.grey[400], size: 28),
                              Text('Scroll for more', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 