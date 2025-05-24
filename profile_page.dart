import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:growater/auth/login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });

      const cloudName = 'dg95lwpl5';
      const uploadPreset = 'flutter_unsigned';

      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        final imageUrl = responseData['secure_url'];

        // Optionally update Firebase user's photoURL
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Update the photoURL in Firestore
          FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'photoURL': imageUrl,
          });

          // Also update Firebase Auth profile photo URL
          await user.updatePhotoURL(imageUrl);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded to Cloudinary')),
        );

        setState(() {
          _profileImage = File(pickedFile.path); // Locally used image
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloudinary upload failed')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo selected')),
      );
    }
  }

  Future<Map<String, dynamic>> _getNotificationPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Green Header with Title and Logo
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade400,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Image.asset(
                        'assets/growater_logo.png',
                        scale: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ✅ User Info and Profile Picture in a Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Editable Fields
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EditableField(
                          label: "User Name",
                          initialValue: user?.displayName ?? "Unknown",
                          onSave: (value) async {
                            if (value.isNotEmpty) {
                              await user?.updateDisplayName(value);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Username updated successfully')),
                              );
                            }
                          },
                        ),
                        EditableField(
                          label: "Email",
                          initialValue: user?.email ?? "Unknown",
                          isEditable: false,
                        ),
                        EditableField(
                          label: "Password",
                          initialValue: "********",
                          isEditable: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Right: Profile Picture (Updated with FutureBuilder)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black,
                          child: const CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black,
                          child: const Icon(Icons.error, size: 40, color: Colors.white),
                        );
                      }

                      String? imageUrl = snapshot.data?.get('photoURL');

                      // Check if imageUrl is null or empty, then use the default avatar
                      if (imageUrl == null || imageUrl.isEmpty) {
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black,
                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                        );
                      }

                      return CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black,
                        backgroundImage: NetworkImage(imageUrl),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const ChangePasswordButton(label: "Change Password"),
                  ElevatedButton(
                    onPressed: _uploadPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text("Upload Picture", style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Notification Preferences
            FutureBuilder<Map<String, dynamic>>(
              future: _getNotificationPrefs(),
              builder: (context, snapshot) {
                final prefs = snapshot.data ?? {};
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Notification Preferences",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      NotificationToggle(
                        label: "Email Notifications",
                        initialValue: prefs['emailNotifications'] ?? false,
                      ),
                      NotificationToggle(
                        label: "Push Notifications",
                        initialValue: prefs['pushNotifications'] ?? false,
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // ✅ Delete & Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  DeleteButton(label: "Delete Account"),
                  LogoutButton(label: "Logout"),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
// 🟦 Reusable Widgets

class EditableField extends StatefulWidget {
  final String label;
  final String initialValue;
  final bool isEditable;
  final Function(String)? onSave;

  const EditableField({
    super.key,
    required this.label,
    required this.initialValue,
    this.isEditable = true,
    this.onSave,
  });

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      border: const OutlineInputBorder(),
                    ),
                  )
                : Text(
                    "${widget.label}: ${_controller.text}",
                    style: const TextStyle(
                      color: Colors.black,
                    ),
                  ),
          ),
          if (widget.isEditable)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing && widget.onSave != null) {
                  widget.onSave!(_controller.text.trim());
                }
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
    );
  }
}

class ChangePasswordButton extends StatelessWidget {
  final String label;
  const ChangePasswordButton({super.key, required this.label});

  Future<void> _changePassword(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newPassword = passwordController.text.trim();
                if (newPassword.isNotEmpty) {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await user.updatePassword(newPassword);

                      // Show the SnackBar BEFORE closing the dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated successfully')),
                      );

                      // Close the dialog
                      Navigator.pop(context);
                    }
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.message}')),
                    );
                  }
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _changePassword(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightBlue.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}

class NotificationToggle extends StatefulWidget {
  final String label;
  final bool initialValue;

  const NotificationToggle({
    super.key,
    required this.label,
    required this.initialValue,
  });

  @override
  State<NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<NotificationToggle> {
  late bool isOn;
  final user = FirebaseAuth.instance.currentUser;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    isOn = widget.initialValue;
    _fetchPreference();
  }

  Future<void> _fetchPreference() async {
    if (user == null) return;
    String field;
    if (widget.label == "Email Notifications") {
      field = "emailNotifications";
    } else if (widget.label == "Push Notifications") {
      field = "pushNotifications";
    } else if (widget.label == "SMS Notifications") {
      field = "smsNotifications";
    } else {
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists && doc.data() != null && doc.data()![field] != null) {
      setState(() {
        isOn = doc.data()![field] as bool;
      });
    }
  }

  Future<void> _updatePreference(bool value) async {
    if (user == null) return;
    setState(() => _loading = true);
    String field;
    if (widget.label == "Email Notifications") {
      field = "emailNotifications";
    } else if (widget.label == "Push Notifications") {
      field = "pushNotifications";
    } else if (widget.label == "SMS Notifications") {
      field = "smsNotifications";
    } else {
      setState(() => _loading = false);
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({field: value}, SetOptions(merge: true));
    setState(() {
      isOn = value;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.label),
          _loading
              ? const SizedBox(
                  width: 40,
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Switch(
                  value: isOn,
                  onChanged: (value) {
                    _updatePreference(value);
                  },
                ),
        ],
      ),
    );
  }
}

class DeleteButton extends StatelessWidget {
  final String label;
  const DeleteButton({super.key, required this.label});

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Login()),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Please re-authenticate to delete your account.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _confirmDeleteAccount(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}

class LogoutButton extends StatelessWidget {
  final String label;
  const LogoutButton({super.key, required this.label});

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _confirmLogout(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}
