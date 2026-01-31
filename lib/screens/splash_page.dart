import 'package:flutter/material.dart';
import '../authentication/authentication_gate.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    /// Wait 2 seconds then navigate to AuthenticationGate
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthenticationGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            /// Top-left circle (using #FFB901)
            Positioned(
              top: -10,
              left: -150,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFB901), // <- updated color
                ),
              ),
            ),

            /// Top-right circle
            Positioned(
              top: -130,
              right: -130,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFB901), // <- updated color
                ),
              ),
            ),

            /// Bottom-left circle
            Positioned(
              bottom: -210,
              left: -420,
              child: Container(
                width: 600,
                height: 600,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                   color: Color(0xFFFFB901), // <- updated color
                ),
              ),
            ),

            /// Bottom-right circle
            Positioned(
              bottom: 220,
              right: -270,
              child: Container(
                width:350,
                height:350,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                   color: Color(0xFFFFB901), // <- updated color
                ),
              ),
            ),

            /// Center logo
            Center(
              child: Image.asset(
                'assets/images/qabila_logo_text.png', // Your logo image
                width: 140,
                height: 140,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
