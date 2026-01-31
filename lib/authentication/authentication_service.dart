import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------- SIGN UP ----------------
  Future<String?> signup({
    required String email,
    required String password,
  }) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      await userCred.user?.sendEmailVerification();

      // Sign out user until verified
      await _auth.signOut();

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _mapSignupError(e.code);
    }
  }

  // ---------------- LOGIN ----------------
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!userCred.user!.emailVerified) {
        await _auth.signOut();
        return 'Please verify your email before logging in.';
      }

      return null; // login success
    } on FirebaseAuthException catch (e) {
      return _mapLoginError(e.code);
    }
  }

  // ---------------- GOOGLE SIGN IN ----------------
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();

      if (googleUser == null) return 'Google sign-in cancelled.';

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null; // success
    } catch (_) {
      return 'Google sign-in failed.';
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------- ERROR MAPPING ----------------
  String _mapSignupError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return 'Signup failed. Please try again.';
    }
  }

  String _mapLoginError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  // ---------------- AUTH STATE ----------------
  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
