import 'package:flutter/material.dart';
import 'package:growater/features/home_content.dart';
import 'package:growater/features/myplants_page.dart';
import 'package:growater/features/notifications_page.dart';
import 'package:growater/features/add_plants_page.dart';
import 'package:growater/features/history_page.dart';
import 'package:growater/features/profile_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeContent(),  // The main dashboard page
    NotificationsPage(),
    AddPlantPage(),
    HistoryPage(),
    ProfilePage(),
  
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Displays the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue, // Active icon color
        unselectedItemColor: Colors.black, // Inactive icon color
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Notifications",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 40), // Bigger add button
            label: "Add Plant",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
