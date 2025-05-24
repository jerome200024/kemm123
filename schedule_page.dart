import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchedulePage extends StatefulWidget {
  final String plantName;
  final String imageUrl;

  const SchedulePage({
    super.key,
    required this.plantName,
    required this.imageUrl,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> schedules = [
    {"time": "10:00 AM", "enabled": false},
    {"time": "5:00 PM", "enabled": false},
  ];
  String duration = "00:00:00"; // Default

  bool isEditingName = false;
  late String plantName;
  late TextEditingController _nameController;

  int? editingTimeIndex;
  TextEditingController timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    plantName = widget.plantName;
    _nameController = TextEditingController(text: plantName);
    fetchPlantDataFromFirestore();
  }

  Future<void> fetchPlantDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .where('name', isEqualTo: widget.plantName)
        .where('imageUrl', isEqualTo: widget.imageUrl)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      // Duration
      final rawDuration = data['duration'];
      if (rawDuration != null) {
        final int totalSeconds = rawDuration is int ? rawDuration : int.tryParse(rawDuration.toString()) ?? 0;
        final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
        final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          duration = "$hours:$minutes:$seconds";
        });
      }
      // Schedules (if you save them as a List in Firestore)
      if (data['schedules'] != null) {
        final List<dynamic> firestoreSchedules = data['schedules'];
        setState(() {
          schedules = firestoreSchedules.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    }
  }

  Future<void> updatePlantName(String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .where('name', isEqualTo: widget.plantName)
        .where('imageUrl', isEqualTo: widget.imageUrl)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({'name': newName});
    }
  }

  Future<void> saveSchedulesAndDuration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .where('name', isEqualTo: widget.plantName)
        .where('imageUrl', isEqualTo: widget.imageUrl)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      // Convert duration string back to seconds
      final parts = duration.split(':');
      int totalSeconds = 0;
      if (parts.length == 3) {
        totalSeconds = (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
      await query.docs.first.reference.update({
        'schedules': schedules,
        'duration': totalSeconds,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedules and duration saved!')),
      );
    }
  }

  Future<void> editDurationDialog() async {
    final controller = TextEditingController(text: duration);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Duration (HH:MM:SS)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            hintText: 'HH:MM:SS',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      // Validate format
      final parts = result.split(':');
      if (parts.length == 3 &&
          parts.every((p) => int.tryParse(p) != null && int.parse(p) >= 0)) {
        setState(() {
          duration = result;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid format. Use HH:MM:SS')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Green Header with Title and Logo
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
                      "Schedule",
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
          const SizedBox(height: 10),
          // Back arrow
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Plant image and name
          Column(
            children: [
              const SizedBox(height: 4),
              widget.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.imageUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset('assets/potted-plant.png', width: 90, height: 90),
                      ),
                    )
                  : Image.asset('assets/potted-plant.png', width: 90, height: 90),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isEditingName
                      ? SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            onSubmitted: (value) async {
                              if (value.trim().isEmpty) return;
                              setState(() {
                                plantName = value.trim();
                                isEditingName = false;
                              });
                              await updatePlantName(plantName);
                            },
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            ),
                          ),
                        )
                      : Text(
                          plantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () {
                      setState(() {
                        isEditingName = true;
                        _nameController.text = plantName;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Schedules and duration
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ...schedules.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var sched = entry.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              editingTimeIndex == idx
                                  ? SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: timeController,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                        ),
                                        onSubmitted: (value) {
                                          if (value.trim().isEmpty) return;
                                          setState(() {
                                            schedules[idx]["time"] = value.trim();
                                            editingTimeIndex = null;
                                          });
                                        },
                                      ),
                                    )
                                  : Text(
                                      sched["time"],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                              const SizedBox(width: 10),
                              const Text(
                                "Everyday",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: sched["enabled"],
                          onChanged: (val) {
                            setState(() {
                              schedules[idx]["enabled"] = val;
                            });
                          },
                          activeColor: Colors.greenAccent.shade400,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            setState(() {
                              editingTimeIndex = idx;
                              timeController.text = schedules[idx]["time"];
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            setState(() {
                              schedules.removeAt(idx);
                              if (editingTimeIndex == idx) editingTimeIndex = null;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                // Duration row
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Duration:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        duration,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: editDurationDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // Add a new schedule with default values
                            schedules.add({
                              "time": "08:00 AM",
                              "enabled": false,
                            });
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade100,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("Add Schedule"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saveSchedulesAndDuration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade400,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("Save"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


