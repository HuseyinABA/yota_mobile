import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/trips/operation_screen.dart';

class MainLayout extends StatefulWidget {
  final String userRole; // Sisteme giren kişinin yetkisi (ADMIN veya MUAVIN)

  const MainLayout({super.key, required this.userRole});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    
    // ROL KONTROLÜ: ADMIN tüm sekmeleri görür, MUAVIN sadece operasyonu görür.
    if (widget.userRole == 'ADMIN') {
      _pages = [const DashboardScreen(), const OperationScreen()];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Padding(padding: EdgeInsets.only(bottom: 4.0), child: Icon(Icons.dashboard_customize)),
          label: 'Merkez İstasyon',
        ),
        BottomNavigationBarItem(
          icon: Padding(padding: EdgeInsets.only(bottom: 4.0), child: Icon(Icons.radar)),
          label: 'Canlı Takip',
        ),
      ];
    } else {
      // MUAVIN MODU: Sadece Kokpit ekranı yüklenir
      _pages = [const OperationScreen()];
      _navItems = []; // Alt menü gizlenecek
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17),
      body: _pages[_currentIndex],
      // SADECE ADMIN'E ALT MENÜ GÖSTER
      bottomNavigationBar: widget.userRole == 'ADMIN' 
        ? Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.2), width: 1)),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: const Color(0xFF131C2D),
              selectedItemColor: Colors.cyanAccent,
              unselectedItemColor: Colors.white38,
              showUnselectedLabels: true,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              items: _navItems,
            ),
          ) 
        : null, // Muavin için alt menü (NavigationBar) yok, tam ekran çalışma alanı!
    );
  }
}