import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_chat_app/authentication/logout_helper.dart';
import 'package:my_chat_app/screens/friends_page.dart';
import 'one_to_one_page.dart';


class MessagesPagePersonal extends StatefulWidget {
  const MessagesPagePersonal({super.key});

  @override
  State<MessagesPagePersonal> createState() => _MessagesPagePersonalState();
}

class _MessagesPagePersonalState extends State<MessagesPagePersonal> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Uint8List? _decodeBase64(String? base64String) {
    if (base64String == null) return null;
    try {
      return Uint8List.fromList(base64.decode(base64String));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(int timestampMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<bool> _isLastMessageSeen(String chatId, String currentUserId) async {
    final snapshot = await _firestore
        .collection('personal_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return true;

    final lastMessage = snapshot.docs.first.data();
    final seenBy = lastMessage.containsKey('seenBy')
        ? List<String>.from(lastMessage['seenBy'])
        : <String>[];

    return seenBy.contains(currentUserId);
  }

  void _goToMoreChats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsPage(), // navigate to FriendsPage
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB901),
        foregroundColor: Colors.black,
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            onPressed: () => LogoutHelper.confirmLogout(context),
            icon: Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('personal_chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;
          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'No chats yet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            );
          }

          // Sort by lastMessageTime descending
          chats.sort((a, b) {
            final aTime = a['lastMessageTime'] ?? 0;
            final bTime = b['lastMessageTime'] ?? 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final participants = List<String>.from(chat['participants']);
              final friendId = participants.firstWhere(
                (id) => id != currentUserId,
              );

              final lastMessage = chat['lastMessage'] ?? '';
              final lastMessageTime = chat['lastMessageTime'] ?? 0;
              final chatId = chat.id;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(friendId).get(),
                builder: (context, friendSnapshot) {
                  if (!friendSnapshot.hasData) return const SizedBox();

                  final friendData = friendSnapshot.data!;
                  final friendName = friendData['profileName'] ?? 'Unknown';
                  final friendProfile = _decodeBase64(
                    friendData['profileImage'],
                  );

                  return FutureBuilder<bool>(
                    future: _isLastMessageSeen(chatId, currentUserId),
                    builder: (context, seenSnapshot) {
                      final isSeen = seenSnapshot.hasData
                          ? seenSnapshot.data!
                          : true;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isSeen ? 1 : 4,
                        color: isSeen ? Colors.white : Colors.yellow[50],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: friendProfile != null
                                ? MemoryImage(friendProfile)
                                : null,
                            backgroundColor: Colors.grey[300],
                            child: friendProfile == null
                                ? Text(
                                    friendName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            friendName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: isSeen ? Colors.black : Colors.black87,
                            ),
                          ),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: isSeen
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (!isSeen)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (!isSeen) const SizedBox(width: 6),
                                  Text(
                                    _formatTime(lastMessageTime),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OneToOnePage(
                                  friendId: friendId,
                                  friendName: friendName,
                                  friendProfileImage:
                                      friendData['profileImage'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMoreChats,
        backgroundColor: const Color(0xFFFFB901),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}
