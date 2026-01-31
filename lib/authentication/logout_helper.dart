import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_chat_app/screens/entry_page.dart';


class LogoutHelper {
  /// Call this method to show a logout confirmation dialog and perform logout
  static Future<void> confirmLogout(BuildContext context) async {
    final auth = FirebaseAuth.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.signOut();
      await GoogleSignIn().signOut();

      if (!context.mounted) return;

      // Navigate to entry page and remove all previous pages
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EntryPage()),
        (route) => false,
      );
    }
  }
}
