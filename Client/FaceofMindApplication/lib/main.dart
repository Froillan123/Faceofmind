import 'package:flutter/material.dart';

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
              const Spacer(),
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
                      MaterialPageRoute(builder: (context) => const AuthScreen(initialTab: 1)),
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
                      MaterialPageRoute(builder: (context) => const AuthScreen(initialTab: 0)),
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
    );
  }
}

class AuthScreen extends StatefulWidget {
  final int initialTab; // 0 = Login, 1 = Sign Up
  const AuthScreen({super.key, this.initialTab = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool isLogin;
  bool rememberMe = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    isLogin = widget.initialTab == 0;
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 36),
                // TODO: Replace this Icon with your logo image.
                // To use your own image, place it in the assets/images/ directory (see instructions below).
                Icon(Icons.psychology, size: 80, color: mainColor),
                const SizedBox(height: 16),
                const Text(
                  'FaceofMind',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin ? 'Your mental health companion' : 'Create your account',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5A6473),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Tab Switcher
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isLogin ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Login',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLogin ? mainColor : Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !isLogin ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Sign Up',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !isLogin ? mainColor : Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Email Field
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                    hintText: 'Enter your email',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: mainColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isLogin) ...[
                  const SizedBox(height: 10),
                  // Last Name Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Last Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
                      hintText: 'Enter your last name',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: mainColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // First Name Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'First Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
                      hintText: 'Enter your first name',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: mainColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // Password Field
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                    hintText: 'Enter your password',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: mainColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey.shade400,
                      ),
                      onPressed: () => setState(() => passwordVisible = !passwordVisible),
                    ),
                  ),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    obscureText: !confirmPasswordVisible,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                      hintText: 'Confirm your password',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: mainColor, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () => setState(() => confirmPasswordVisible = !confirmPasswordVisible),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Remember Me & Forgot Password
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: mainColor,
                      onChanged: (val) => setState(() => rememberMe = val ?? false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Text(
                      'Remember Me',
                      style: TextStyle(
                        color: mainColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(foregroundColor: mainColor),
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Login/Sign Up Button
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
                    onPressed: () {},
                    child: Text(isLogin ? 'Login' : 'Sign Up'),
                  ),
                ),
                const SizedBox(height: 18),
                // Privacy text
                Text.rich(
                  TextSpan(
                    text: 'Your privacy and security matter to us.\n',
                    style: const TextStyle(
                      color: Color(0xFF5A6473),
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: 'Learn more',
                        style: TextStyle(color: mainColor, fontWeight: FontWeight.w500),
                      ),
                      const TextSpan(
                        text: ' about how we protect your data.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
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
