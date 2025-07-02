import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'services/api_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String get _otpValue => _otpController.text.trim();

  Future<void> _verifyOtp() async {
    if (_otpValue.length != 6) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Invalid OTP'),
          content: const Text('Enter all 6 digits'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => isLoading = true);
    final res = await ApiService.verifyOtp(widget.email, _otpValue);
    setState(() => isLoading = false);
    if (res['success']) {
      Navigator.of(context).popUntil((route) => route.isFirst); // Go back to login
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('OTP Verification Failed'),
          content: Text(res['message'] ?? 'OTP verification failed'),
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
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Verify Email Address',
                        style: TextStyle(fontSize: 24 * fontScale, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We Have Sent Code To Your Email',
                        style: TextStyle(fontSize: 16 * fontScale, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * fontScale, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _otpController,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28 * fontScale, letterSpacing: 2),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter 6-digit code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: mainColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20 * fontScale),
                          ),
                          child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 