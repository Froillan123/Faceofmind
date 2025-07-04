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
import 'notification_screen.dart';
import 'consult_page.dart';

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
  
  // Notification count (dummy for now)
  int _notificationCount = 2;

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

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    ApiService.onJwtExpired = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    };
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
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade100,
                  child: Text(
                    initials.toUpperCase(),
                    style: TextStyle(fontSize: 48, color: mainColor, fontWeight: FontWeight.w600),
                  ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total Sessions: $_sessionCount', style: TextStyle(fontSize: 18, color: mainColor, fontWeight: FontWeight.w500)),
                      IconButton(
                        icon: Icon(Icons.refresh, color: mainColor, size: 20),
                        tooltip: 'Refresh Sessions',
                        onPressed: () async {
                          setState(() => _loadingSessions = true);
                          final count = await ApiService.fetchSessionCount(_token ?? '');
                          setState(() {
                            _sessionCount = count;
                            _loadingSessions = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: () => _showEditProfileModal(context),
                    child: const Text('EDIT PROFILE'),
                  ),
                ),
              ],
            ),
          );
  }

  void _showEditProfileModal(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _EditProfileDialog(
        email: _email ?? '',
        firstName: _firstName ?? '',
        lastName: _lastName ?? '',
      ),
    );
    if (result != null && userId != null) {
      final res = await ApiService.updateUserProfile(_token ?? '', userId, result['first_name']!, result['last_name']!);
      if (res['success'] == true) {
        setState(() {
          _firstName = result['first_name'];
          _lastName = result['last_name'];
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to update profile')));
        }
      }
    }
  }

  Widget _buildHomeTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Emotion Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
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

  Widget _buildAiTab(BuildContext context) {
    final mainColor = const Color(0xFF22C55E);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Image.asset(
              'assets/images/logo.png',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan Now',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            const Text(
              'Just Be Yourself and Relax, Be At Peace',
              style: TextStyle(fontSize: 17, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Click The Button below.',
              style: TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF5CD581).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hold the mic if you want to talk, and release it for the AI to respond.',
                style: TextStyle(fontSize: 15, color: Color(0xFF22C55E), fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultPage()));
                },
                icon: const Icon(Icons.android, size: 28),
                label: const Text('Consult Now!', style: TextStyle(fontSize: 20)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  disabledBackgroundColor: mainColor,
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                tooltip: 'Notifications',
                onPressed: () {
                  setState(() {
                    _notificationCount = 0; // Clear notifications on open
                  });
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
              : _buildAiTab(context),
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

class _EditProfileDialog extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  const _EditProfileDialog({super.key, required this.email, required this.firstName, required this.lastName});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: widget.email),
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context);
            });
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context, {
                'first_name': _firstNameController.text.trim(),
                'last_name': _lastNameController.text.trim(),
              });
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 