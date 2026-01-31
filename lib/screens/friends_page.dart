import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_chat_app/authentication/logout_helper.dart';
import 'one_to_one_page.dart';
import 'other_user_profile_page.dart';
import 'dart:convert';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> incomingRequests = [];
  List<Map<String, dynamic>> outgoingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Color _avatarColor(String text) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return text.isEmpty
        ? Colors.grey
        : colors[text.codeUnitAt(0) % colors.length];
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final friendIds = List<String>.from(data['friends'] ?? []);
    final incomingIds = List<String>.from(data['incomingFriendRequests'] ?? []);
    final outgoingIds = List<String>.from(data['outgoingFriendRequests'] ?? []);

    Future<List<Map<String, dynamic>>> getUsers(List<String> ids) async {
      List<Map<String, dynamic>> list = [];
      for (var id in ids) {
        final d = await _firestore.collection('users').doc(id).get();
        if (d.exists) {
          final m = d.data()!;
          m['uid'] = id;
          list.add(m);
        }
      }
      return list;
    }

    final f = await getUsers(friendIds);
    final incoming = await getUsers(incomingIds);
    final outgoing = await getUsers(outgoingIds);

    setState(() {
      friends = f;
      incomingRequests = incoming;
      outgoingRequests = outgoing;
      _isLoading = false;
    });
  }

  Future<void> _acceptRequest(String uid) async {
    final currentUid = _auth.currentUser!.uid;

    await _firestore.collection('users').doc(currentUid).update({
      'friends': FieldValue.arrayUnion([uid]),
      'incomingFriendRequests': FieldValue.arrayRemove([uid]),
    });
    await _firestore.collection('users').doc(uid).update({
      'friends': FieldValue.arrayUnion([currentUid]),
      'outgoingFriendRequests': FieldValue.arrayRemove([currentUid]),
    });

    _loadData();
  }

  Future<void> _rejectRequest(String uid) async {
    final currentUid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUid).update({
      'incomingFriendRequests': FieldValue.arrayRemove([uid]),
    });
    await _firestore.collection('users').doc(uid).update({
      'outgoingFriendRequests': FieldValue.arrayRemove([currentUid]),
    });
    _loadData();
  }

  Future<void> _unfriend(String uid) async {
    final currentUid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUid).update({
      'friends': FieldValue.arrayRemove([uid]),
    });
    await _firestore.collection('users').doc(uid).update({
      'friends': FieldValue.arrayRemove([currentUid]),
    });
    _loadData();
  }

  // ---------------- UNFRIEND WITH CONFIRMATION ----------------
  Future<void> _confirmUnfriend(String uid, String friendName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfriend'),
        content: Text(
          'Are you sure you want to remove $friendName from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _unfriend(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB901),
        foregroundColor: Colors.black,
        title: const Text(
          'Friends',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => LogoutHelper.confirmLogout(context),
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------ FRIEND REQUESTS ------------------
              Text(
                'Friend Requests (${incomingRequests.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (incomingRequests.isEmpty)
                const Text(
                  'No pending friend requests.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...incomingRequests.map((user) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _avatarColor(user['username'] ?? ''),
                      child: Text((user['username'] ?? '?')[0].toUpperCase()),
                    ),
                    title: Text(user['profileName'] ?? ''),
                    subtitle: Text('@${user['username']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _acceptRequest(user['uid']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectRequest(user['uid']),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OtherUserProfilePage(userId: user['uid']),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // ------------------ FRIENDS ------------------
              Text(
                'Friends (${friends.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (friends.isEmpty)
                const Text(
                  'You have no friends yet.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...friends.map((user) {
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: _avatarColor(user['username'] ?? ''),
                      backgroundImage: user['profileImage'] != null
                          ? MemoryImage(base64.decode(user['profileImage']))
                          : null,
                      child: user['profileImage'] == null
                          ? Text(
                              (user['username'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(user['profileName'] ?? ''),
                    subtitle: Text('@${user['username']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OneToOnePage(
                                friendId: user['uid'],
                                friendName: user['profileName'] ?? '',
                                friendProfileImage: user['profileImage'],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.person_remove,
                            color: Colors.red,
                          ),
                          onPressed: () => _confirmUnfriend(
                            user['uid'],
                            user['profileName'] ?? 'this user',
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OtherUserProfilePage(userId: user['uid']),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
