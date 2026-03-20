import 'package:flutter/material.dart';
import 'package:mingym/screens/workouts_screen.dart';
import 'package:mingym/screens/stats_screen.dart';
import 'package:mingym/screens/settings_screen.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const WorkoutsScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: const Border(
            top: BorderSide(color: Colors.white12, width: 1),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 25),
          height: 70, 
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), 
            
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12), 
              width: 1
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(255, 26, 26, 26).withValues(alpha: 0.6),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.02),
                blurRadius: 1,
                spreadRadius: 1,
              ),
            ]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.fitness_center, 'Workouts', 0),
              _buildDivider(),
              _buildNavItem(Icons.bar_chart, 'Stats', 1),
              _buildDivider(),
              _buildNavItem(Icons.settings, 'Settings', 2),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.blue.shade200 : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue.shade200 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}