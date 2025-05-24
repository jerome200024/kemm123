import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPlantPage extends StatefulWidget {
  const AddPlantPage({super.key});

  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  File? selectedImage;
  final picker = ImagePicker();

  bool isEditingPlantName = false;
  bool isEditingSuitableMoisture = false;
  bool isEditingCurrentMoisture = false;
  bool isEditingDuration = false;
  bool isLoading = false;

  String plantName = "Plant 1";
  double suitableMoistureStart = 60.0;
  double suitableMoistureEnd = 80.0;
  double currentMoisture = 0.0;
  int durationSeconds = 0; // Store duration as seconds

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dg95lwpl5';
    const uploadPreset = 'flutter_unsigned';

    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final json = jsonDecode(resStr);
      return json['secure_url'];
    } else {
      print('Upload failed: ${response.statusCode}');
      return null;
    }
  }

  Future<void> savePlantData() async {
    if (isLoading) return; // Prevent double tap
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }
    if (plantName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plant name.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final imageUrl = await uploadImageToCloudinary(selectedImage!);
      if (imageUrl == null) throw Exception("Image upload failed");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user");

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .doc();

      await docRef.set({
        'name': plantName,
        'imageUrl': imageUrl,
        'suitableMoistureStart': suitableMoistureStart,
        'suitableMoistureEnd': suitableMoistureEnd,
        'currentMoisture': currentMoisture,
        'duration': durationSeconds, // Save as seconds
        'timestamp': DateTime.now().toIso8601String(),
      });

      // After await docRef.set({...});
      final plantData = {
        'id': docRef.id,
        'name': plantName,
        'suitableMoistureStart': suitableMoistureStart,
        'currentMoisture': currentMoisture,
      };
      await _checkAndNotifyLowMoisture(context, plantData);

      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Plant saved successfully!')),
      // );
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Plant saved successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close dialog only
              child: const Text('OK'),
            ),
          ],
        ),
      ).then((_) {
        // Reset UI for next plant after dialog is closed
        if (mounted) {
          setState(() {
            selectedImage = null;
            plantName = "Plant 1";
            suitableMoistureStart = 60.0;
            suitableMoistureEnd = 80.0;
            currentMoisture = 0.0;
            durationSeconds = 0;
            isEditingPlantName = false;
            isEditingSuitableMoisture = false;
            isEditingCurrentMoisture = false;
            isEditingDuration = false;
          });
        }
      });

      // Remove this:
      // await Future.delayed(const Duration(milliseconds: 500)); // Let the snackbar show
      // if (mounted) Navigator.of(context).pop();

      // Reset UI for next plant
      setState(() {
        selectedImage = null;
        plantName = "Plant 1";
        suitableMoistureStart = 60.0;
        suitableMoistureEnd = 80.0;
        currentMoisture = 0.0;
        durationSeconds = 0;
        isEditingPlantName = false;
        isEditingSuitableMoisture = false;
        isEditingCurrentMoisture = false;
        isEditingDuration = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Future<void> fetchLatestSensorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use your actual plant document ID here
    const plantId = 'k2FPxQVViezGDgxSFuN8';

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      setState(() {
        currentMoisture = (data?['currentMoisture'] as num?)?.toDouble() ?? 0.0;
        // Optionally, fetch temperature and humidity as well:
        // double temperature = (data?['temperature'] as num?)?.toDouble() ?? 0.0;
        // double humidity = (data?['humidity'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLatestSensorData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header
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
                          "Add Plant",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        Image.asset('assets/growater_logo.png', scale: 10),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      // Image + buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          selectedImage != null
                              ? Image.file(selectedImage!, width: 100, height: 100, fit: BoxFit.cover)
                              : Image.asset('assets/potted-plant.png', width: 100, height: 100),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton(
                                onPressed: () => pickImage(ImageSource.gallery),
                                child: const Text("Select Photo"),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => pickImage(ImageSource.camera),
                                child: const Text("Take a Photo"),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // Editable fields
                      _editableRow("Plant Name", plantName, isPlantName: true),
                      const SizedBox(height: 30),
                      _editableRow(
                        "Suitable soil moisture",
                        "${suitableMoistureStart.toStringAsFixed(1)}% - ${suitableMoistureEnd.toStringAsFixed(1)}%",
                        isSuitableMoisture: true,
                      ),
                      const SizedBox(height: 30),
                      _editableRow(
                        "Current soil moisture",
                        "${currentMoisture.toStringAsFixed(1)}%",
                        isCurrentMoisture: true,
                      ),
                      const SizedBox(height: 30),
                      _editableRow(
                        "Duration",
                        _formatDuration(durationSeconds),
                        isDuration: true,
                      ),
                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text("Connect"),
                          ),
                          ElevatedButton(
                            onPressed: isLoading ? null : savePlantData,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text("Save"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _editableRow(
    String label,
    String value, {
    bool isPlantName = false,
    bool isSuitableMoisture = false,
    bool isCurrentMoisture = false,
    bool isDuration = false,
  }) {
    bool isEditing = isPlantName
        ? isEditingPlantName
        : isSuitableMoisture
            ? isEditingSuitableMoisture
            : isCurrentMoisture
                ? isEditingCurrentMoisture
                : isEditingDuration;

    if (isEditing) {
      return _buildTextField(label, value, (newValue) {
        setState(() {
          if (isPlantName) {
            plantName = newValue;
            isEditingPlantName = false;
          } else if (isSuitableMoisture) {
            final parts = newValue.split('-');
            if (parts.length == 2) {
              suitableMoistureStart = double.tryParse(parts[0].trim()) ?? 60.0;
              suitableMoistureEnd = double.tryParse(parts[1].trim()) ?? 80.0;
              isEditingSuitableMoisture = false;
            }
          } else if (isCurrentMoisture) {
            currentMoisture = double.tryParse(newValue) ?? 0.0;
            isEditingCurrentMoisture = false;
          } else if (isDuration) {
            // Parse HH:MM:SS to seconds
            final parts = newValue.split(':');
            int h = 0, m = 0, s = 0;
            if (parts.length == 3) {
              h = int.tryParse(parts[0]) ?? 0;
              m = int.tryParse(parts[1]) ?? 0;
              s = int.tryParse(parts[2]) ?? 0;
            } else if (parts.length == 2) {
              m = int.tryParse(parts[0]) ?? 0;
              s = int.tryParse(parts[1]) ?? 0;
            } else if (parts.length == 1) {
              s = int.tryParse(parts[0]) ?? 0;
            }
            durationSeconds = h * 3600 + m * 60 + s;
            isEditingDuration = false;
          }
        });
      });
    }

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              if (isPlantName) isEditingPlantName = true;
              if (isSuitableMoisture) isEditingSuitableMoisture = true;
              if (isCurrentMoisture) isEditingCurrentMoisture = true;
              if (isDuration) isEditingDuration = true;
            });
          },
          child: const Icon(Icons.edit, size: 18),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onSubmitted) {
    final controller = TextEditingController(text: value);
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            keyboardType: label == "Duration" ? TextInputType.datetime : TextInputType.text,
            onSubmitted: (newValue) {
              if (newValue.trim().isEmpty) return;
              onSubmitted(newValue);
            },
          ),
        ),
        TextButton(
          child: const Text("OK"),
          onPressed: () {
            final newValue = controller.text;
            if (newValue.trim().isEmpty) return;
            onSubmitted(newValue);
          },
        ),
      ],
    );
  }

  Future<void> _checkAndNotifyLowMoisture(BuildContext context, Map<String, dynamic> plant) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (plant['currentMoisture'] < plant['suitableMoistureStart']) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final existing = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('plantName', isEqualTo: plant['name'])
          .where('date', isEqualTo: today.toIso8601String())
          .get();

      if (existing.docs.isEmpty) {
        final formattedTime =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'text': "${plant['name']} is low soil moisture, water your plant now",
          'time': formattedTime,
          'timestamp': now,
          'plantName': plant['name'],
          'date': today.toIso8601String(),
        });
      }
    }
  }
}

class SomeOtherPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Some Other Page")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => AddPlantPage()),
            );
          },
          child: Text("Go to Add Plant Page"),
        ),
      ),
    );
  }
}
