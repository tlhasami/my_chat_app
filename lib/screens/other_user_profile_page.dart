import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'one_to_one_page.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String userId;

  const OtherUserProfilePage({super.key, required this.userId});

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  List<String> _mutualGroups = [];
  bool _isLoading = true;

  bool _isFriend = false;
  bool _requestSent = false;
  bool _incomingRequest = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Load other user data
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();

      // Groups of current user
      final myGroups = await _firestore
          .collection('groups')
          .where('members', arrayContains: currentUser.uid)
          .get();

      // Groups of other user
      final otherGroups = await _firestore
          .collection('groups')
          .where('members', arrayContains: widget.userId)
          .get();

      final myGroupNames = myGroups.docs.map((e) => e['name'] as String).toSet();
      final otherGroupNames = otherGroups.docs.map((e) => e['name'] as String).toSet();

      // Friendship status
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentData = currentUserDoc.data()!;

      final friends = List<String>.from(currentData['friends'] ?? []);
      final outgoingRequests = List<String>.from(currentData['outgoingFriendRequests'] ?? []);
      final incomingRequests = List<String>.from(currentData['incomingFriendRequests'] ?? []);

      setState(() {
        _userData = userDoc.data();
        _mutualGroups = myGroupNames.intersection(otherGroupNames).toList();
        _isFriend = friends.contains(widget.userId);
        _requestSent = outgoingRequests.contains(widget.userId);
        _incomingRequest = incomingRequests.contains(widget.userId);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Uint8List? _decodeBase64(String? base64String) {
    if (base64String == null) return null;
    return base64.decode(base64String);
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _firestore.collection('users').doc(currentUser.uid);
    final otherRef = _firestore.collection('users').doc(widget.userId);

    await currentRef.update({
      'outgoingFriendRequests': FieldValue.arrayUnion([widget.userId])
    });
    await otherRef.update({
      'incomingFriendRequests': FieldValue.arrayUnion([currentUser.uid])
    });

    setState(() {
      _requestSent = true;
    });
  }

  Future<void> _cancelFriendRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _firestore.collection('users').doc(currentUser.uid);
    final otherRef = _firestore.collection('users').doc(widget.userId);

    await currentRef.update({
      'outgoingFriendRequests': FieldValue.arrayRemove([widget.userId])
    });
    await otherRef.update({
      'incomingFriendRequests': FieldValue.arrayRemove([currentUser.uid])
    });

    setState(() {
      _requestSent = false;
    });
  }

  Future<void> _acceptRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _firestore.collection('users').doc(currentUser.uid);
    final otherRef = _firestore.collection('users').doc(widget.userId);

    await currentRef.update({
      'friends': FieldValue.arrayUnion([widget.userId]),
      'incomingFriendRequests': FieldValue.arrayRemove([widget.userId]),
    });

    await otherRef.update({
      'friends': FieldValue.arrayUnion([currentUser.uid]),
      'outgoingFriendRequests': FieldValue.arrayRemove([currentUser.uid]),
    });

    setState(() {
      _isFriend = true;
      _incomingRequest = false;
    });
  }

  Future<void> _rejectRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _firestore.collection('users').doc(currentUser.uid);
    final otherRef = _firestore.collection('users').doc(widget.userId);

    await currentRef.update({
      'incomingFriendRequests': FieldValue.arrayRemove([widget.userId])
    });
    await otherRef.update({
      'outgoingFriendRequests': FieldValue.arrayRemove([currentUser.uid])
    });

    setState(() {
      _incomingRequest = false;
    });
  }

  Future<void> _unfriend() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _firestore.collection('users').doc(currentUser.uid);
    final otherRef = _firestore.collection('users').doc(widget.userId);

    await currentRef.update({
      'friends': FieldValue.arrayRemove([widget.userId])
    });
    await otherRef.update({
      'friends': FieldValue.arrayRemove([currentUser.uid])
    });

    setState(() {
      _isFriend = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    final profileImage = _decodeBase64(_userData!['profileImage']);
    final profileName = _userData!['profileName'] ?? '';
    final username = _userData!['username'] ?? '';
    final dob = _userData!['dob'] != null
        ? DateTime.parse(_userData!['dob'])
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text("User Profile")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              child: profileImage != null
                  ? ClipOval(
                      child: Image.memory(profileImage, fit: BoxFit.cover, width: 120, height: 120),
                    )
                  : Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 12),
            Text(profileName,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('@$username', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            _infoTile(
              Icons.cake,
              'Date of Birth',
              dob != null ? DateFormat('dd MMM yyyy').format(dob) : 'N/A',
            ),

            _infoTile(
              Icons.calendar_today,
              'Member Since',
              DateFormat('MMMM yyyy').format(
                (_auth.currentUser!.metadata.creationTime!),
              ),
            ),

            const Divider(),
            const SizedBox(height: 12),

            // ---------------- FRIEND BUTTONS ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_isFriend) ...[
                    // Send Message + Unfriend
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OneToOnePage(
                                      friendId: widget.userId,
                                      friendName: profileName),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Send Message"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _unfriend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Unfriend"),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_incomingRequest) ...[
                    // Accept / Reject
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _acceptRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Accept"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _rejectRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Reject"),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_requestSent) ...[
                    // Cancel request
                    ElevatedButton(
                      onPressed: _cancelFriendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Cancel Request"),
                    ),
                  ] else ...[
                    // Add friend
                    ElevatedButton(
                      onPressed: _sendFriendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Add Friend"),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Mutual Groups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            if (_mutualGroups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No mutual groups'),
              )
            else
              ..._mutualGroups.map(
                (g) => ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(g),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
