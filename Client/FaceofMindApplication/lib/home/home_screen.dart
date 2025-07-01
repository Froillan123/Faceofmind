import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _initAndFetchSessionCount();
  }

  Future<void> _initAndFetchSessionCount() async {
    String? token = widget.token;
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwt_token') ?? '';
    }
    _token = token;
    final count = await ApiService.fetchSessionCount(token ?? '');
    setState(() {
      _sessionCount = count;
      _loadingSessions = false;
    });
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
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight,
            child: Column(
              children: [
                if (_selectedIndex == 0) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _loadingSessions
                        ? const CircularProgressIndicator()
                        : Text('Total Sessions: $_sessionCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ),
      ),
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