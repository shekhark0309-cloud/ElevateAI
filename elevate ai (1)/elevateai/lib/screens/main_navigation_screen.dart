import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'team_finder_screen.dart';
import 'campus_connect_screen.dart'; // Using this for Digital Twin for now
import 'slg_visualization.dart'; // Using this for Focus/SLG

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TeamFinderScreen(),
    const CampusConnectScreen(), // Placeholder for Digital Twin
    const SLGVisualizationScreen(), // Placeholder for Focus
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6200EE),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),      activeIcon: Icon(Icons.home),         label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined),     activeIcon: Icon(Icons.group),        label: 'Teams'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline),     activeIcon: Icon(Icons.people),       label: 'Campus'),
          BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_outlined), activeIcon: Icon(Icons.bubble_chart), label: 'SLG'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),     activeIcon: Icon(Icons.person),       label: 'Profile'),
        ],
      ),
    );
  }
}
