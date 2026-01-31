import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfileProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  List<String> _joinedGroups = [];
  bool _isLoading = true;

  Map<String, dynamic>? get userData => _userData;
  List<String> get joinedGroups => _joinedGroups;
  bool get isLoading => _isLoading;

  Color themeColor = const Color(0xFFFFB901);

  ProfileProvider() {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final groupSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .get();

      _userData = userDoc.data();
      _joinedGroups =
          groupSnapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Uint8List? decodeBase64(String? base64String) {
    if (base64String == null) return null;
    return base64.decode(base64String);
  }

  Color avatarColor(String text) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
    ];
    final index = text.isNotEmpty ? text.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }
}
