import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OneToOnePage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendProfileImage; // optional base64 string

  const OneToOnePage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendProfileImage,
  });

  @override
  State<OneToOnePage> createState() => _OneToOnePageState();
}

class _OneToOnePageState extends State<OneToOnePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String chatDocId = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _firestore.settings = const Settings(persistenceEnabled: true);
    _initChat();
  }

  Uint8List? _decodeBase64(String? base64String) {
    if (base64String == null) return null;
    try {
      return Uint8List.fromList(base64.decode(base64String));
    } catch (_) {
      return null;
    }
  }

  Future<void> _initChat() async {
    final currentUserId = _auth.currentUser!.uid;

    // Check if chat exists
    final query = await _firestore
        .collection('personal_chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(widget.friendId)) {
        chatDocId = doc.id;
        break;
      }
    }

    // Create chat if not exists
    if (chatDocId.isEmpty) {
      final docRef = await _firestore.collection('personal_chats').add({
        'participants': [currentUserId, widget.friendId],
        'lastMessage': '',
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      });
      chatDocId = docRef.id;
    }

    if (mounted) setState(() => isLoading = false);
  }

  void sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || chatDocId.isEmpty) return;

    final currentUserId = _auth.currentUser!.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Add message with seenBy list
    _firestore
        .collection('personal_chats')
        .doc(chatDocId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': text,
      'timestamp': timestamp,
      'seenBy': [currentUserId], // mark sender as seen
      'status': 'sent',
    });

    // Update last message
    _firestore.collection('personal_chats').doc(chatDocId).update({
      'lastMessage': text,
      'lastMessageTime': timestamp,
    });

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ----------------- CLEAR CHAT FOR EVERYONE -----------------
  Future<void> _clearChatForEveryone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat for Everyone'),
        content: const Text(
            'This will permanently delete all messages in this chat for both users. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final messagesSnapshot = await _firestore
        .collection('personal_chats')
        .doc(chatDocId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var msg in messagesSnapshot.docs) {
      batch.delete(msg.reference);
    }
    await batch.commit();

    // Update lastMessage
    await _firestore.collection('personal_chats').doc(chatDocId).update({
      'lastMessage': '',
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ----------------- CLEAR CHAT FOR ME -----------------
  Future<void> _clearChatForMe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat for Me'),
        content: const Text(
            'This will hide all messages from your view only.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final currentUserId = _auth.currentUser!.uid;

    final messagesSnapshot = await _firestore
        .collection('personal_chats')
        .doc(chatDocId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var msg in messagesSnapshot.docs) {
      batch.update(msg.reference, {
        'hiddenFor': FieldValue.arrayUnion([currentUserId])
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final friendProfile = _decodeBase64(widget.friendProfileImage);
    final currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB901),
        foregroundColor: Colors.black,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  friendProfile != null ? MemoryImage(friendProfile) : null,
              backgroundColor: Colors.grey[300],
              child: friendProfile == null
                  ? Text(widget.friendName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.friendName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_everyone') {
                _clearChatForEveryone();
              } else if (value == 'clear_me') {
                _clearChatForMe();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_everyone',
                child: Text('Clear chat for everyone'),
              ),
              const PopupMenuItem(
                value: 'clear_me',
                child: Text('Clear chat for me'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('personal_chats')
                  .doc(chatDocId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter out messages hidden for current user
                final messages = snapshot.data!.docs.where((msg) {
                  final msgData = msg.data() as Map<String, dynamic>;
                  final hiddenFor = msgData.containsKey('hiddenFor')
                      ? List<String>.from(msgData['hiddenFor'])
                      : <String>[];
                  return !hiddenFor.contains(currentUserId);
                }).toList();

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final msgData = msg.data() as Map<String, dynamic>;
                    final isMe = msgData['senderId'] == currentUserId;
                    final text = msgData['text'] ?? '';
                    final timestamp = msgData['timestamp'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            msgData['timestamp'])
                        : null;

                    final seenBy = msgData.containsKey('seenBy')
                        ? List<String>.from(msgData['seenBy'])
                        : <String>[];

                    // Auto-mark as read
                    if (!isMe && !seenBy.contains(currentUserId)) {
                      _firestore
                          .collection('personal_chats')
                          .doc(chatDocId)
                          .collection('messages')
                          .doc(msg.id)
                          .update({
                        'seenBy': FieldValue.arrayUnion([currentUserId]),
                        'status': 'read',
                      });
                    }

                    final showGreenDot =
                        !isMe && !seenBy.contains(currentUserId);

                    Icon? tickIcon;
                    if (isMe) {
                      tickIcon = msgData['status'] == 'read'
                          ? const Icon(Icons.done_all,
                              size: 16, color: Colors.white)
                          : const Icon(Icons.done,
                              size: 16, color: Colors.white);
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe
                                ? const Radius.circular(12)
                                : const Radius.circular(0),
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showGreenDot)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (showGreenDot) const SizedBox(width: 4),
                                if (timestamp != null)
                                  Text(
                                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.black54),
                                  ),
                                if (tickIcon != null) ...[
                                  const SizedBox(width: 4),
                                  tickIcon,
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: sendMessage,
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
