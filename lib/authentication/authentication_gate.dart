import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_chat_app/screens/home_page.dart';
import 'package:my_chat_app/screens/entry_page.dart';
import 'package:my_chat_app/authentication/verify_email_page.dart';

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user != null) {
          // User logged in
          if (user.emailVerified || user.providerData.any((p) => p.providerId == 'google.com')) {
            // Verified or Google sign-in
            return const HomePage();
          } else {
            // Show verify email screen
            return VerifyEmailPage(user: user,);
          }
        } else {
          return const EntryPage();
        }
      },
    );
  }
}
