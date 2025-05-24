// filepath: lib/core/services/firebase_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadPhotoAndSaveUrl(File photo, String userId) async {
  try {
    // Upload the photo to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref().child('profile_photos/$userId.jpg');
    await storageRef.putFile(photo);

    // Get the download URL
    final downloadUrl = await storageRef.getDownloadURL();

    // Save the download URL in Firestore
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    await userDoc.set({'photoUrl': downloadUrl}, SetOptions(merge: true));
  } catch (e) {
    print('Error uploading photo: $e');
  }
}