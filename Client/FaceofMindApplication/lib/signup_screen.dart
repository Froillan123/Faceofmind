import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'verify_otp_screen.dart';
import 'login_screen.dart';
import 'main.dart' show showCustomToast;
import 'reset_password_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;
  bool emailValid = true;
  bool passwordValid = true;
  bool confirmPasswordValid = true;
  bool firstNameValid = true;
  bool lastNameValid = true;
  bool rememberMe = false;
  int step = 1;
  bool isLoading = false;

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'At least 8 characters and 1 number';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'At least 8 characters and 1 number';
    return null;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      emailValid = emailController.text.contains('@');
      firstNameValid = firstNameController.text.isNotEmpty;
      lastNameValid = lastNameController.text.isNotEmpty;
    });
    if (emailValid && firstNameValid && lastNameValid) {
      setState(() { step = 2; });
    }
  }

  void _backStep() {
    setState(() { step = 1; });
  }

  Future<void> _handleSignup() async {
    setState(() {
      passwordValid = _validatePassword(passwordController.text) == null;
      confirmPasswordValid = passwordController.text == confirmPasswordController.text;
      isLoading = true;
    });
    if (!passwordValid || !confirmPasswordValid) {
      setState(() { isLoading = false; });
      return;
    }
    final email = emailController.text.trim();
    final res = await ApiService.register(
      email,
      passwordController.text,
      firstNameController.text.trim(),
      lastNameController.text.trim(),
    );
    setState(() { isLoading = false; });
    if (res['success']) {
      passwordController.clear();
      firstNameController.clear();
      lastNameController.clear();
      confirmPasswordController.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => VerifyOtpScreen(email: email)),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Registration Failed'),
          content: Text(res['message'] ?? 'Registration failed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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
                    'Create your account',
                    style: TextStyle(fontSize: 18, color: Color(0xFF5A6473), fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (step == 1) ...[
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
                    if (!emailValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Email is required and must be valid', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Last Name', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lastNameController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
                        hintText: 'Enter your last name',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: lastNameValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: lastNameValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: lastNameValid ? mainColor : Colors.red, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          lastNameValid = val.isNotEmpty;
                        });
                      },
                    ),
                    if (!lastNameValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Last name is required', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('First Name', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: firstNameController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
                        hintText: 'Enter your first name',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: firstNameValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: firstNameValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: firstNameValid ? mainColor : Colors.red, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          firstNameValid = val.isNotEmpty;
                        });
                      },
                    ),
                    if (!firstNameValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('First name is required', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 24),
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
                        onPressed: _nextStep,
                        child: const Text('Next'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(fontSize: 16)),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: Text('Sign In', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ] else ...[
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
                          passwordValid = _validatePassword(val) == null;
                          confirmPasswordValid = val == confirmPasswordController.text;
                        });
                      },
                    ),
                    if (_validatePassword(passwordController.text) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_validatePassword(passwordController.text)!, style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Confirm Password', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !confirmPasswordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                        hintText: 'Confirm your password',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: confirmPasswordValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: confirmPasswordValid ? Colors.grey.shade200 : Colors.red, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: confirmPasswordValid ? mainColor : Colors.red, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(confirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade400),
                          onPressed: () => setState(() => confirmPasswordVisible = !confirmPasswordVisible),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          confirmPasswordValid = val == passwordController.text;
                        });
                      },
                    ),
                    if (!confirmPasswordValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Passwords do not match', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
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
                        onPressed: isLoading ? null : _handleSignup,
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Sign Up'),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _backStep,
                        style: TextButton.styleFrom(
                          foregroundColor: mainColor,
                          padding: const EdgeInsets.only(left: 0, top: 8, bottom: 8),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(fontSize: 16)),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: Text('Sign In', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
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