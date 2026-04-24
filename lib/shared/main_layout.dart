import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/trips/operation_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 1; // Uygulama açıldığında direkt Operasyon Paneli (1. index) gelsin

  final List<Widget> _pages = [
    const DashboardScreen(),
    const OperationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), // Derin karanlık arka plan
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.2), width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF131C2D), // Neon koyu lacivert
          selectedItemColor: Colors.cyanAccent, // Seçili ikon rengi
          unselectedItemColor: Colors.white38, // Seçilmeyen ikon rengi
          showUnselectedLabels: true,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4.0), child: Icon(Icons.dashboard_customize)),
              label: 'Özet Panel',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4.0), child: Icon(Icons.radar)),
              label: 'Canlı Takip',
            ),
          ],
        ),
      ),
    );
  }
}