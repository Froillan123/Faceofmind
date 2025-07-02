import 'package:flutter/material.dart';
import 'main.dart';
import 'services/api_service.dart';

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
  bool isLoading = false;

  String? _validatePassword(String value) {
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'At least one number';
    return null;
  }

  Future<void> _sendResetCode() async {
    setState(() { isLoading = true; });
    final res = await ApiService.requestPasswordReset(emailController.text.trim());
    setState(() { isLoading = false; });
    if (res['success']) {
      setState(() { sent = true; });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Code Sent'),
          content: const Text('Reset code sent to your email!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(res['message'] ?? 'Failed to send reset code'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _verifyCode() {
    if (codeController.text.length == 6) {
      setState(() { codeVerified = true; });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Code Verified'),
          content: const Text('Code verified! Enter new password.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Code'),
          content: const Text('Invalid code'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    final passwordError = _validatePassword(passwordController.text);
    setState(() {
      passwordValid = passwordError == null;
      confirmPasswordValid = passwordController.text == confirmPasswordController.text;
    });
    if (!passwordValid) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Password'),
          content: Text(passwordError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (!confirmPasswordValid) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Mismatch'),
          content: const Text('Passwords do not match'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() { isLoading = true; });
    final res = await ApiService.resetPassword(
      emailController.text.trim(),
      codeController.text.trim(),
      passwordController.text,
    );
    setState(() { isLoading = false; });
    if (res['success']) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(res['message'] ?? 'Failed to reset password'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      onPressed: isLoading ? null : _sendResetCode,
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
                      onPressed: isLoading ? null : _resetPassword,
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