import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'profile_setup_page.dart';
import 'other_user_profile_page.dart';
import 'package:my_chat_app/authentication/logout_helper.dart';
import 'package:my_chat_app/screens/entry_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  List<String> _joinedGroups = [];
  List<Map<String, dynamic>> _friends = [];

  bool _groupsExpanded = false;
  bool _friendsExpanded = false;
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // IMPORTANT

  final Color _themeColor = const Color(0xFFFFB901);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ---------------- REAUTHENTICATION ----------------
  Future<bool> _reauthenticateUser() async {
    try {
      final user = _currentUser;
      if (user == null) return false;

      final providerId = user.providerData.first.providerId;

      // -------- GOOGLE LOGIN --------
      if (providerId == 'google.com') {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return false;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
        return true;
      }

      // -------- EMAIL / PASSWORD --------
      final password = await showDialog<String>(
        context: context,
        builder: (_) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Re-authentication required'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (password == null || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password cannot be empty.")),
          );
        }
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      String message = 'Re-authentication failed. Please try again.';

      if (e.code == 'wrong-password') {
        message = 'The password you entered is incorrect.';
      }else if (e.code == 'user-not-found') {
        message = 'User not found.';
      } else if (e.code == 'invalid-credential') {
        message = 'The credential is invalid. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-authentication failed.')),
        );
      }
      return false;
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null || _hasLoadedOnce) return;

    _hasLoadedOnce = true;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      final groupSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: _currentUser.uid)
          .get();

      final friendsUids = List<String>.from(userDoc.data()?['friends'] ?? []);

      final friendsData = <Map<String, dynamic>>[];
      for (var uid in friendsUids) {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['uid'] = doc.id;
          friendsData.add(data);
        }
      }

      setState(() {
        _userData = userDoc.data();
        _joinedGroups = groupSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _friends = friendsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Uint8List? _decodeBase64(String? base64String) {
    if (base64String == null) return null;
    return base64.decode(base64String);
  }

  Color _avatarColor(String text) {
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

  // ---------------- UNFRIEND ----------------
  Future<void> _unfriend(String friendUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfriend Confirmation'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'friends': FieldValue.arrayRemove([friendUid]),
      });

      await _firestore.collection('users').doc(friendUid).update({
        'friends': FieldValue.arrayRemove([_currentUser.uid]),
      });

      setState(() {
        _friends.removeWhere((f) => f['uid'] == friendUid);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ---------------- DELETE ACCOUNT ----------------
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete your account, remove you from all friends and groups. Are you sure?',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = _currentUser!.uid;

      final friends = List<String>.from(_userData?['friends'] ?? []);
      for (var fUid in friends) {
        await _firestore.collection('users').doc(fUid).update({
          'friends': FieldValue.arrayRemove([uid]),
        });
      }

      final groups = await _firestore
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      for (var g in groups.docs) {
        await _firestore.collection('groups').doc(g.id).update({
          'members': FieldValue.arrayRemove([uid]),
        });
      }

      final reauthed = await _reauthenticateUser();
      if (!reauthed) return;

      await _firestore.collection('users').doc(uid).delete();
      await _currentUser.delete();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EntryPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting account: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _themeColor,
          foregroundColor: Colors.black,
          title: const Text(
            'Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () => LogoutHelper.confirmLogout(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return const Scaffold(body: Center(child: Text('Profile not found')));
    }

    final profileImage = _decodeBase64(_userData!['profileImage']);
    final profileName = _userData!['profileName'] ?? 'Unknown';
    final username = _userData!['username'] ?? 'unknown';
    final dobStr = _userData!['dob'];
    final dob = dobStr != null ? DateTime.parse(dobStr) : null;
    final about = _userData!['about'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.black,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => LogoutHelper.confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // -------- HEADER --------
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: _avatarColor(username),
                    child: profileImage != null
                        ? ClipOval(
                            child: Image.memory(
                              profileImage,
                              width: 118,
                              height: 118,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profileName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ProfileSetupPage(isEditingProfile: true),
                        ),
                      ).then((_) {
                        _hasLoadedOnce = false;
                        _isLoading = true;
                        _loadProfile();
                      });
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Customize Profile'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

            // -------- PERSONAL INFO --------
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.person, 'Username', username),
                  if (about.isNotEmpty)
                    _buildInfoRow(Icons.info_outline, 'About', about),
                  if (dob != null)
                    _buildInfoRow(
                      Icons.cake,
                      'Date of Birth',
                      DateFormat('dd MMM yyyy').format(dob),
                    ),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Member Since',
                    DateFormat(
                      'MMMM yyyy',
                    ).format(_currentUser!.metadata.creationTime!),
                  ),
                ],
              ),
            ),

            // -------- FRIENDS --------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Friends (${_friends.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      _friendsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _themeColor,
                    ),
                    onTap: () =>
                        setState(() => _friendsExpanded = !_friendsExpanded),
                  ),
                  if (_friendsExpanded)
                    ..._friends.map(
                      (f) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _avatarColor(f['username'] ?? ''),
                          backgroundImage: f['profileImage'] != null
                              ? MemoryImage(_decodeBase64(f['profileImage'])!)
                              : null,
                          child: f['profileImage'] == null
                              ? Text(
                                  f['username'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(f['profileName']),
                        subtitle: Text('@${f['username']}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.person_remove,
                            color: Colors.red,
                          ),
                          onPressed: () => _unfriend(f['uid']),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfilePage(userId: f['uid']),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // -------- GROUPS --------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Joined Groups (${_joinedGroups.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      _groupsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _themeColor,
                    ),
                    onTap: () =>
                        setState(() => _groupsExpanded = !_groupsExpanded),
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _themeColor,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
