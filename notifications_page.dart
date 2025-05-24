import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
                      "Notifications",
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

          const SizedBox(height: 20),

          // ✅ Notification list
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('plants')
                  .get(),
              builder: (context, plantSnapshot) {
                if (!plantSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final activePlantNames = plantSnapshot.data!.docs
                    .map((doc) => doc['name'] as String?)
                    .where((name) => name != null)
                    .toSet();
                final activePlantIds = plantSnapshot.data!.docs.map((doc) => doc.id).toSet();

                return StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('notifications')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.toList();

                    if (docs.isEmpty) {
                      return const Center(child: Text('No notifications.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final Timestamp? timestamp = data['timestamp'];
                        String timeAgo = '';
                        if (timestamp != null) {
                          final date = timestamp.toDate();
                          final now = DateTime.now();
                          final difference = now.difference(date);
                          if (difference.inSeconds < 60) {
                            timeAgo = 'just now';
                          } else if (difference.inMinutes < 60) {
                            timeAgo = '${difference.inMinutes} min ago';
                          } else if (difference.inHours < 24) {
                            timeAgo = '${difference.inHours} hr ago';
                          } else {
                            timeAgo = '${difference.inDays} days ago';
                          }
                        }
                        return NotificationCard(
                          text: data['text'] ?? '',
                          time: timeAgo,
                          plantName: data['plantName'] ?? '',
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String text;
  final String time;
  final String? plantName;

  const NotificationCard({
    super.key,
    required this.text,
    required this.time,
    this.plantName,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plantName != null && plantName!.isNotEmpty)
                  Text(
                    plantName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                Text(text, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

Future<void> createNotification(String plantName, String userId, String text) async {
  final today = DateTime.now();
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  // Check if a notification for this plant and date already exists
  final existing = await firestore
      .collection('users')
      .doc(currentUser!.uid)
      .collection('notifications')
      .where('plantName', isEqualTo: plantName)
      .where('date', isEqualTo: today.toIso8601String())
      .get();

  if (existing.docs.isEmpty) {
    // Create notification
    await firestore.collection('users').doc(currentUser.uid).collection('notifications').add({
      'plantName': plantName,
      'text': text,
      'date': today.toIso8601String(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
