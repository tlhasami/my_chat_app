import 'package:flutter/material.dart';
import 'package:my_chat_app/screens/signup_page.dart';
import 'package:my_chat_app/screens/login_page.dart';

class EntryPage extends StatelessWidget {
  const EntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Logo in top ~40%
            SizedBox(height: screenHeight * 0.1),
            Center(
              child: Image.asset(
                'assets/images/qabila_logo_text.png',
                width: 180,
                height: 180,
              ),
            ),
        
            /// Spacer
            const Spacer(),
        
            /// Bottom panel
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xFFFFB901), // Yellow background
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
        
                  SizedBox(height:10),
                  /// Large Welcome Text
                  const Text(
                    "Welcome",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
        
                  const SizedBox(height: 10),
        
                  /// 3-line message
                  const Text(
                    "Let's Get Started\nConnect with people who matter to you.\nLog in or sign up to begin chatting.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
        
                  const SizedBox(height: 30),
        
                  /// Sign In Button (black text, white bg)
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to Sign In
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
        
                  const SizedBox(height: 20),
        
                  /// Sign Up Button (white text, black bg)
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      /// Sign Up Button
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
        
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
