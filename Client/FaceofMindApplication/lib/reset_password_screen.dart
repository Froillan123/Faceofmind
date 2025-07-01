import 'package:flutter/material.dart';
import 'main.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool sent = false;
  bool codeVerified = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;
  bool passwordValid = true;
  bool confirmPasswordValid = true;

  String? _validatePassword(String value) {
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'At least one number';
    return null;
  }

  void _sendResetCode() {
    setState(() { sent = true; });
    showCustomToast(context, 'Reset code sent to your email!', success: true);
  }

  void _verifyCode() {
    if (codeController.text.length == 6) {
      setState(() { codeVerified = true; });
      showCustomToast(context, 'Code verified! Enter new password.', success: true);
    } else {
      showCustomToast(context, 'Invalid code', success: false);
    }
  }

  void _resetPassword() {
    final passwordError = _validatePassword(passwordController.text);
    setState(() {
      passwordValid = passwordError == null;
      confirmPasswordValid = passwordController.text == confirmPasswordController.text;
    });
    if (!passwordValid) {
      showCustomToast(context, passwordError!, success: false);
      return;
    }
    if (!confirmPasswordValid) {
      showCustomToast(context, 'Passwords do not match', success: false);
      return;
    }
    showCustomToast(context, 'Password reset successful! Please login.', success: true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.of(context).size.width;
    final minWidth = 320.0;
    final fontScale = width < 400 ? 0.85 : 1.0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Reset Password', style: TextStyle(fontSize: 20 * fontScale, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: mainColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!sent) ...[
                    const SizedBox(height: 32),
                    Text('Enter your email', style: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                        hintText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _sendResetCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * fontScale),
                      ),
                      child: const Text('Send Reset Password'),
                    ),
                  ] else if (!codeVerified) ...[
                    const SizedBox(height: 32),
                    Text('Enter the code sent to your email', style: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                        hintText: 'Reset Code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * fontScale),
                      ),
                      child: const Text('Verify Code'),
                    ),
                  ] else ...[
                    const SizedBox(height: 32),
                    Text('Enter new password', style: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: !passwordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                        hintText: 'New Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !confirmPasswordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                        hintText: 'Confirm Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * fontScale),
                      ),
                      child: const Text('Reset Password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 