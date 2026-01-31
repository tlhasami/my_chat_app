import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  final bool isEditingProfile;

  const ProfileSetupPage({super.key, required this.isEditingProfile});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final profileNameController = TextEditingController();
  final usernameController = TextEditingController();
  final aboutController = TextEditingController();

  DateTime? selectedDob;
  File? selectedImage;
  String? base64Image;

  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;

  final Color _themeColor = const Color(0xFFFFB901);

  @override
  void initState() {
    super.initState();
    if (widget.isEditingProfile) {
      _loadExistingProfile();
    }
  }

  Future<void> _loadExistingProfile() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    profileNameController.text = data['profileName'] ?? '';
    usernameController.text = data['username'] ?? '';
    aboutController.text = data['about'] ?? '';
    selectedDob = data['dob'] != null ? DateTime.parse(data['dob']) : null;

    if (data['profileImage'] != null) {
      base64Image = data['profileImage'];
      final bytes = base64Decode(base64Image!);
      final tempFile = await File(
        '${Directory.systemTemp.path}/profile.png',
      ).writeAsBytes(bytes);
      selectedImage = tempFile;
    }

    setState(() {});
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      selectedImage = File(image.path);
      base64Image = base64Encode(bytes);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDob ?? DateTime(2002),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _themeColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;

    final profileName = profileNameController.text.trim();
    final username = usernameController.text.trim();

    if (profileName.isEmpty || username.isEmpty || selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile name, username, and DOB are required"),
        ),
      );
      return;
    }

    final validUsernameRegExp = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!validUsernameRegExp.hasMatch(username)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Username can only contain letters, numbers, '.', '-', or '_'",
          ),
        ),
      );
      return;
    }

    final usernameQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    final profileNameQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('profileName', isEqualTo: profileName)
        .get();

    final usernameExists = usernameQuery.docs.any((doc) => doc.id != user!.uid);
    final profileNameExists = profileNameQuery.docs.any(
      (doc) => doc.id != user!.uid,
    );

    if (usernameExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username is already taken")),
      );
      return;
    }

    if (profileNameExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile name is already taken")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'profileName': profileName,
      'username': username,
      'about': aboutController.text.trim(),
      'dob': selectedDob?.toIso8601String(),
      'profileImage': base64Image,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!widget.isEditingProfile && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: true,
      appBar: widget.isEditingProfile
          ? AppBar(
              backgroundColor: _themeColor,
              title: const Text("Edit Profile"),
            )
          : null ,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.isEditingProfile) ...[
                        const SizedBox(height: 30),
                        Text(
                          "Profile Setup",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _themeColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            "Complete your profile to continue",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Avatar
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          child: CircleAvatar(
                            radius: 55,
                            backgroundImage: selectedImage != null
                                ? FileImage(selectedImage!)
                                : null,
                            child: selectedImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: _themeColor,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: profileNameController,
                                decoration: InputDecoration(
                                  labelText: "Profile Name",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: usernameController,
                                decoration: InputDecoration(
                                  labelText: "Username",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _themeColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: _themeColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        selectedDob == null
                                            ? "Select Date of Birth"
                                            : "${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: aboutController,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  labelText: "About",
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _themeColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                  ),
                                  onPressed: _saveProfile,
                                  child: Text(
                                    widget.isEditingProfile
                                        ? "Save Changes"
                                        : "Continue",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    profileNameController.dispose();
    usernameController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}
