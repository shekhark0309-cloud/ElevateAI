import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'team_finder_screen.dart';
import 'campus_connect_screen.dart';
import '../services/native_navigation_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 2) {
      // Direct jump to Native Campus OS Hub or stay in Flutter Campus Connect?
      // Let's use Flutter Campus Connect for now as it exists.
      setState(() => _selectedIndex = index);
    } else if (index == 3) {
      // SLG Index -> Open Native Focus Mode
      NativeNavigationService.openFocusMode(context);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const TeamFinderScreen(),
    const CampusConnectScreen(),
    const SizedBox.shrink(), // Placeholder for Native Focus
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
        onTap: _onItemTapped,
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
          BottomNavigationBarItem(icon: Icon(Icons.timer_outlined),      activeIcon: Icon(Icons.timer),        label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),     activeIcon: Icon(Icons.person),       label: 'Profile'),
        ],
      ),
    );
  }
}
