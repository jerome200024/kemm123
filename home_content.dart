import 'dart:io';
import 'package:flutter/material.dart';
import 'package:growater/core/services/weather_service.dart';
import 'package:growater/features/myplants_page.dart';
import 'package:growater/controller/user_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:growater/features/schedule_page.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String location = '';
  String temperature = '';
  String weather = '';
  String dateTime = '';
  String iconCode = '';
  List<Map<String, String>> savedPlants = [];

  final WeatherService weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    UserController.ensureUserDocumentExists();
    loadWeather();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadSavedPlants();
  }

  void loadSavedPlants() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      final photo = args['photo'] as String?;
      final name = args['name'] as String?;
      if (photo != null && name != null) {
        setState(() {
          savedPlants.add({'photo': photo, 'name': name});
          if (savedPlants.length > 3) {
            savedPlants = savedPlants.sublist(savedPlants.length - 3);
          }
        });
      }
    }
  }

  Future<void> loadWeather() async {
    try {
      final position = await weatherService.getCurrentLocation();
      final weatherData = await weatherService.getWeather(position.latitude, position.longitude);
      final now = DateTime.now();
      final formattedDate = '${_getWeekday(now.weekday)}, ${_getMonth(now.month)} ${now.day}';
      final formattedTime = '${_formatHour(now)}:${_formatMinute(now)} ${now.hour >= 12 ? 'PM' : 'AM'}';

      setState(() {
        temperature = '${weatherData['main']['temp'].toStringAsFixed(0)}°';
        weather = weatherData['weather'][0]['main'];
        iconCode = weatherData['weather'][0]['icon'];
        location = '${weatherData['name']}, ${weatherData['sys']['country']}';
        dateTime = '$formattedDate|$formattedTime';
        print('Weather debug: $temperature, $weather, $iconCode, $location, $dateTime');
      });
    } catch (e) {
      print('Error loading weather: $e');
    }
  }

  String _getWeekday(int weekday) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  String _getMonth(int month) => [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][month - 1];
  String _formatHour(DateTime now) => (now.hour % 12 == 0 ? 12 : now.hour % 12).toString();
  String _formatMinute(DateTime now) => now.minute.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: HomeContentBody(
        dateTime: dateTime,
        temperature: temperature,
        iconCode: iconCode,
        location: location,
        savedPlants: savedPlants,
      ),
    );
  }
}

class HomeContentBody extends StatelessWidget {
  final String temperature;
  final String location;
  final String dateTime;
  final String iconCode;
  final List<Map<String, String>> savedPlants;

  const HomeContentBody({
    super.key,
    required this.temperature,
    required this.location,
    required this.dateTime,
    required this.iconCode,
    required this.savedPlants,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Dashboard",
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Image.asset('assets/growater_logo.png', scale: 8),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              height: 230,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    dateTime.contains('|') ? dateTime.split('|')[0] : '',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        temperature.isNotEmpty ? temperature : '--',
                        style: const TextStyle(
                            fontSize: 60, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (iconCode.isNotEmpty)
                            Image.network(
                              'http://openweathermap.org/img/wn/$iconCode@4x.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          else
                            const Icon(Icons.cloud, size: 60, color: Colors.grey),
                          const SizedBox(height: 4),
                          Text(location.isNotEmpty ? location : 'No location', style: const TextStyle(fontSize: 16)),
                          Text(
                            dateTime.contains('|') ? dateTime.split('|')[1] : '',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("My Plants",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyPlantsPage()),
                    );
                  },
                  child: const Text("See all", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            Container(
              height: 150,
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.greenAccent.shade400,
                borderRadius: BorderRadius.circular(40),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseAuth.instance.currentUser == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('plants')
                        .orderBy('timestamp', descending: true)
                        .limit(3)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Please add your plants",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (index) {
                      if (index >= docs.length) {
                        return const SizedBox(width: 70);
                      }
                      final plant = docs[index].data() as Map<String, dynamic>;
                      final plantName = plant['name'] ?? 'Unnamed';
                      final imageUrl = plant['imageUrl'] ?? '';

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SchedulePage(
                                    plantName: plantName,
                                    imageUrl: imageUrl,
                                  ),
                                ),
                              );
                            },
                            child: plant['imageUrl'] != null && plant['imageUrl'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      plant['imageUrl'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.local_florist, color: Colors.white, size: 60),
                                    ),
                                  )
                                : const Icon(Icons.local_florist, color: Colors.white, size: 60),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plantName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}