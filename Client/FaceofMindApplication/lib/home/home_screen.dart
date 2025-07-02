import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dominant_emotion_chart.dart';
import 'intensity_chart.dart';
import 'quick_actions.dart';
import 'donate_screen.dart';
import 'community_screen.dart';
import 'hotlines_screen.dart';
import 'history_screen.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final String? token;
  const HomeScreen({super.key, this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _sessionCount = 0;
  bool _loadingSessions = true;
  String? _token;
  // Profile data
  String? _firstName;
  String? _lastName;
  String? _email;
  bool _loadingProfile = true;
  List<dynamic> _dominantEmotionChart = [];
  List<dynamic> _intensityChart = [];
  bool _loadingCharts = true;
  bool _refreshingCharts = false;

  final Map<String, Color> _emotionColors = {
    'happy': Color(0xFF5CD581),
    'sad': Color(0xFF7ED6DF),
    'neutral': Color(0xFFB2BEC3),
    'angry': Color(0xFFFF7675),
  };

  static const List<Widget> _pages = <Widget>[
    Center(child: Text('Home', style: TextStyle(fontSize: 32))),
    Center(child: Icon(Icons.smart_toy, size: 80)),
    Center(child: Text('Profile', style: TextStyle(fontSize: 32))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _initAndFetchData();
    _fetchCharts();
  }

  Future<void> _initAndFetchData() async {
    String? token = widget.token;
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwt_token') ?? '';
    }
    _token = token;
    // Fetch session count
    final count = await ApiService.fetchSessionCount(token ?? '');
    // Fetch user_id
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    Map<String, dynamic>? userData;
    if (userId != null && userId > 0) {
      final userRes = await ApiService.fetchUserById(token ?? '', userId);
      if (userRes['success']) {
        userData = userRes['data'];
      }
    }
    setState(() {
      _sessionCount = count;
      _loadingSessions = false;
      _firstName = userData?['first_name'] ?? '';
      _lastName = userData?['last_name'] ?? '';
      _email = userData?['email'] ?? '';
      _loadingProfile = false;
    });
  }

  Future<void> _fetchCharts({bool forceRefresh = false}) async {
    setState(() => _loadingCharts = true);
    String? token = _token;
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwt_token') ?? '';
    }
    final dominant = await ApiService.fetchDominantEmotionChart(token);
    final intensity = await ApiService.fetchIntensityChart(token);
    setState(() {
      _dominantEmotionChart = dominant;
      _intensityChart = intensity;
      _loadingCharts = false;
      _refreshingCharts = false;
    });
  }

  void _refreshCharts() {
    setState(() => _refreshingCharts = true);
    _fetchCharts(forceRefresh: true);
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'Donate':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonateScreen()));
        break;
      case 'Community':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityScreen()));
        break;
      case 'Talk Now Hotlines':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HotlinesScreen()));
        break;
      case 'History':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
        break;
    }
  }

  Widget _buildProfileTab(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final initials = ((_firstName?.isNotEmpty ?? false) ? _firstName![0] : '') + ((_lastName?.isNotEmpty ?? false) ? _lastName![0] : '');
    return _loadingProfile
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade100,
                      child: Text(
                        initials.toUpperCase(),
                        style: TextStyle(fontSize: 48, color: mainColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Icon(Icons.camera_alt, color: mainColor, size: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '${(_firstName ?? '').toUpperCase()} ${(_lastName ?? '').toUpperCase()}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: mainColor, letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _email ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Total Sessions: $_sessionCount', style: TextStyle(fontSize: 18, color: mainColor, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    onPressed: () {},
                    child: const Text('EDIT PROFILE'),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildHomeTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Dominant Emotions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            IconButton(
              icon: _refreshingCharts ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
              onPressed: _refreshingCharts ? null : _refreshCharts,
              tooltip: 'Refresh Charts',
            ),
          ],
        ),
        _loadingCharts
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : DominantEmotionChart(data: _dominantEmotionChart, emotionColors: _emotionColors),
        _loadingCharts
            ? const SizedBox.shrink()
            : IntensityChart(data: _intensityChart),
        QuickActions(onActionTap: _handleQuickAction),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.of(context).size.width;
    final minWidth = 320.0;
    final fontScale = width < 400 ? 0.85 : 1.0;
    return Scaffold(
      appBar: AppBar(
        title: Text('FaceofMind', style: TextStyle(fontSize: 22 * fontScale, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: mainColor,
      ),
      body: _selectedIndex == 0
          ? _buildHomeTab(context)
          : _selectedIndex == 2
              ? _buildProfileTab(context)
              : Center(child: Icon(Icons.smart_toy, size: 80)),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: mainColor,
        unselectedItemColor: Colors.grey.shade400,
        currentIndex: _selectedIndex, 
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 