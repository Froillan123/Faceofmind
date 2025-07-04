import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'verify_otp_screen.dart';
import 'home/home_screen.dart';
import 'reset_password_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<void> main() async {
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
    final height = MediaQuery.of(context).size.height;
    final scale = height < 500 ? (height / 700).clamp(0.6, 1.0) : 1.0;
    final logoSize = 150.0;
    final titleFont = 24.0 * scale;
    final subtitleFont = 14.0 * scale;
    final featureFont = 15.0 * scale;
    final buttonFont = 16.0 * scale;
    final buttonPad = 12.0 * scale;
    final featureIcon = 22.0 * scale;
    final featurePad = 8.0 * scale;
    final featureRowPad = 12.0 * scale;
    final verticalPad = (height < 500) ? 8.0 * scale : 16.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 32 * scale),
                  Center(
                    child: Image.asset('assets/images/Logo.png', height: logoSize),
                  ),
                  SizedBox(height: 32 * scale),
                  Text(
                    'FaceofMind',
                    style: TextStyle(
                      fontSize: titleFont,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    'Your personal mental wellness companion with AI-powered emotional support',
                    style: TextStyle(
                      fontSize: subtitleFont,
                      color: const Color(0xFF5A6473),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24 * scale),
                  FeatureRow(
                    icon: Icons.emoji_emotions,
                    text: 'Emotion Recognition & Voice',
                    color: mainColor,
                    fontSize: featureFont,
                    iconSize: featureIcon,
                    iconPad: featurePad,
                    rowPad: featureRowPad,
                  ),
                  SizedBox(height: verticalPad),
                  FeatureRow(
                    icon: Icons.smart_toy,
                    text: 'AI Mental Health Consultation',
                    color: mainColor,
                    fontSize: featureFont,
                    iconSize: featureIcon,
                    iconPad: featurePad,
                    rowPad: featureRowPad,
                  ),
                  SizedBox(height: verticalPad),
                  FeatureRow(
                    icon: Icons.groups,
                    text: 'Supportive Community',
                    color: mainColor,
                    fontSize: featureFont,
                    iconSize: featureIcon,
                    iconPad: featurePad,
                    rowPad: featureRowPad,
                  ),
                  SizedBox(height: 24 * scale),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: buttonPad),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: buttonFont,
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
                  SizedBox(height: 10 * scale),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300, width: 2),
                        padding: EdgeInsets.symmetric(vertical: buttonPad),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: TextStyle(
                          fontSize: buttonFont * 0.9,
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
                  SizedBox(height: 12 * scale),
                ],
              ),
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
  final double? fontSize;
  final double? iconSize;
  final double? iconPad;
  final double? rowPad;
  const FeatureRow({super.key, required this.icon, required this.text, required this.color, this.fontSize, this.iconSize, this.iconPad, this.rowPad});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(iconPad ?? 12),
          child: Icon(icon, color: color, size: iconSize ?? 32),
        ),
        SizedBox(width: rowPad ?? 20),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize ?? 20,
              color: const Color(0xFF3A3A3A),
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
