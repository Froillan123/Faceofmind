import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'signup_screen.dart';
import 'services/api_service.dart';
import 'verify_otp_screen.dart';
import 'reset_password_screen.dart';
import 'main.dart' show showCustomToast;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool passwordVisible = false;
  bool emailValid = true;
  bool passwordValid = true;
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      emailValid = emailController.text.contains('@');
      passwordValid = passwordController.text.isNotEmpty;
      isLoading = true;
    });
    if (!emailValid || !passwordValid) {
      setState(() { isLoading = false; });
      return;
    }
    final res = await ApiService.login(emailController.text.trim(), passwordController.text);
    if (res['success']) {
      final token = res['data']['access_token'] ?? '';
      final userId = res['data']['user_id'] ?? res['data']['id'];
      if (token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        if (userId != null) {
          await prefs.setInt('user_id', userId is int ? userId : int.tryParse(userId.toString()) ?? 0);
        }
      }
      await Future.delayed(const Duration(seconds: 2)); 
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen(token: token)),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Login Failed'),
          content: Text(res['message'] ?? 'Login failed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    setState(() { isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.of(context).size.width;
    final minWidth = 320.0;
    final fontScale = width < 400 ? 0.85 : 1.0;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Image.asset('assets/images/Logo.png', height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'FaceofMind',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your mental health companion',
                    style: TextStyle(fontSize: 18, color: Color(0xFF5A6473), fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Email
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Email', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                      hintText: 'Enter your email',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: emailValid ? Colors.grey.shade200 : Colors.red, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: emailValid ? Colors.grey.shade200 : Colors.red, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: emailValid ? mainColor : Colors.red, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        emailValid = val.contains('@');
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Password', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                      hintText: 'Enter your password',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: passwordValid ? Colors.grey.shade200 : Colors.red, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: passwordValid ? Colors.grey.shade200 : Colors.red, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: passwordValid ? mainColor : Colors.red, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade400),
                        onPressed: () => setState(() => passwordVisible = !passwordVisible),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        passwordValid = val.isNotEmpty;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: mainColor,
                        onChanged: (val) => setState(() => rememberMe = val ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      Text('Remember Me', style: TextStyle(color: mainColor, fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                          );
                        },
                        style: TextButton.styleFrom(foregroundColor: mainColor),
                        child: const Text('Reset Password'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      onPressed: isLoading ? null : _handleLogin,
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 16)),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: Text('Sign Up', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 