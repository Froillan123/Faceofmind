import 'package:flutter/material.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF22C55E); // Green shade similar to screenshot
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show QR Code', style: TextStyle(color: Color(0xFF1E3354), fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: mainColor),
      ),
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: mainColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/qrcodegcash.png',
                width: 340,
                height: 420,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Column(
            children: [
              Icon(Icons.error_outline, color: mainColor.withOpacity(0.7), size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'This is a single-use code for your use only. Get a new code each time you donate.',
                  style: const TextStyle(
                    color: Color(0xFF1E3354),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 