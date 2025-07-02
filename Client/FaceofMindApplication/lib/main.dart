import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'verify_otp_screen.dart';
import 'home/home_screen.dart';
import 'reset_password_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceofMind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5CD581),
          primary: const Color(0xFF5CD581),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LandingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 48),
                // TODO: Replace this Icon with your logo image.
                // To use your own image, place it in the assets/images/ directory (see instructions below).
                Icon(Icons.psychology, size: 120, color: mainColor),
                const SizedBox(height: 32),
                const Text(
                  'FaceofMind',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your personal mental wellness companion with AI-powered emotional support',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5A6473),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                FeatureRow(
                  icon: Icons.emoji_emotions,
                  text: 'Emotion Recognition & Voice',
                  color: mainColor,
                ),
                const SizedBox(height: 16),
                FeatureRow(
                  icon: Icons.smart_toy,
                  text: 'AI Mental Health Consultation',
                  color: mainColor,
                ),
                const SizedBox(height: 16),
                FeatureRow(
                  icon: Icons.groups,
                  text: 'Supportive Community',
                  color: mainColor,
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text('I already have an account'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const FeatureRow({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF3A3A3A),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// Guide for storing and using your logo image:
// 1. Create a folder named 'images' inside the 'assets' directory at the root of your Flutter project.
//    Example: assets/images/your_logo.png
// 2. Add the image path to your pubspec.yaml under the 'assets:' section:
//      assets:
//        - assets/images/your_logo.png
// 3. Replace the Icon widget with:
//      Image.asset('assets/images/your_logo.png', height: 120)
// 4. Run 'flutter pub get' to update assets.
//
// If you need help with this, just ask!

// Only show the bottom navigation bar after login (on the main/home screen)!
// Example HomeScreen with bottom nav bar:
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(child: Text('Welcome to the app!')), // Replace with your actual home content
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: mainColor,
        unselectedItemColor: Colors.grey.shade400,
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
