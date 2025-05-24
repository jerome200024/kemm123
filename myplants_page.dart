import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'schedule_page.dart';

class MyPlantsPage extends StatefulWidget {
  const MyPlantsPage({super.key});

  @override
  State<MyPlantsPage> createState() => _MyPlantsPageState();
}

class _MyPlantsPageState extends State<MyPlantsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _plants = [];
  double? _temperature;
  double? _humidity;
  StreamSubscription<QuerySnapshot>? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _fetchPlants();
    _listenToSensorData();
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  void _listenToSensorData() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _sensorSubscription = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          _temperature = (data['temperature'] as num?)?.toDouble();
          _humidity = (data['humidity'] as num?)?.toDouble();
        });
      }
    });
  }

  Future<void> _fetchPlants() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('plants')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _plants = snapshot.docs.map((doc) {
          final plant = {
            'id': doc.id,
            'name': doc['name'] ?? '',
            'suitableMoistureStart': doc['suitableMoistureStart'] ?? 0.0,
            'suitableMoistureEnd': doc['suitableMoistureEnd'] ?? 0.0,
            'currentMoisture': doc['currentMoisture'] ?? 0.0,
            'imageUrl': doc['imageUrl'] ?? '',
          };
          _checkAndNotifyLowMoisture(plant);
          return plant;
        }).toList();
      });
    });
  }

  void _deletePlant(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final plantDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(id)
        .get();

    final plantName = plantDoc.data()?['name'];

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(id)
        .delete();

    if (plantName != null) {
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('plantName', isEqualTo: plantName)
          .get();

      for (final doc in notificationsQuery.docs) {
        await doc.reference.delete();
      }
    }

    setState(() {
      _plants.removeWhere((plant) => plant['id'] == id);
    });
  }

  Future<void> _checkAndNotifyLowMoisture(Map<String, dynamic> plant) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (plant['currentMoisture'] < plant['suitableMoistureStart']) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final existing = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('plantName', isEqualTo: plant['name'])
          .where('date', isEqualTo: today.toIso8601String())
          .get();

      if (existing.docs.isEmpty) {
        final formattedTime =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
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

  Future<void> _startWatering(String plantId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final plantRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('plants')
        .doc(plantId);

    await plantRef.update({'watering': true});

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watering started!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
                      "My Plants",
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
          // Temperature & Humidity display
          _temperature != null && _humidity != null
              ? Text(
                  "Temperature: ${_temperature!.toStringAsFixed(1)}°C\nHumidity: ${_humidity!.toStringAsFixed(1)}%",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : const CircularProgressIndicator(),
          const SizedBox(height: 10),
          // Plants list
          Expanded(
            child: _plants.isEmpty
                ? const Center(child: Text("No plants saved yet."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _plants.length,
                    itemBuilder: (context, index) {
                      final plant = _plants[index];
                      return PlantCard(
                        id: plant['id'],
                        name: plant['name'],
                        suitableMoistureStart: plant['suitableMoistureStart'],
                        suitableMoistureEnd: plant['suitableMoistureEnd'],
                        currentMoisture: plant['currentMoisture'],
                        imageUrl: plant['imageUrl'],
                        onDelete: () => _deletePlant(plant['id']),
                        onStartWatering: () => _startWatering(plant['id']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PlantCard extends StatelessWidget {
  final String id;
  final String name;
  final double suitableMoistureStart;
  final double suitableMoistureEnd;
  final double currentMoisture;
  final String imageUrl;
  final VoidCallback onDelete;
  final VoidCallback onStartWatering;

  const PlantCard({
    super.key,
    required this.id,
    required this.name,
    required this.suitableMoistureStart,
    required this.suitableMoistureEnd,
    required this.currentMoisture,
    required this.imageUrl,
    required this.onDelete,
    required this.onStartWatering,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Delete Icon at top right
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant Image or Icon
              imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.local_florist, size: 50),
                      ),
                    )
                  : const Icon(Icons.local_florist, size: 50),
              const SizedBox(width: 16),
              // Plant Info + Buttons
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Current Soil Moisture: ${currentMoisture.toStringAsFixed(1)}%",
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        "Suitable Soil Moisture: ${suitableMoistureStart.toStringAsFixed(1)}% - ${suitableMoistureEnd.toStringAsFixed(1)}%",
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SchedulePage(
                                      plantName: name,
                                      imageUrl: imageUrl,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text("Schedule"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onStartWatering,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text("Start Watering"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
