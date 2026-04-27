import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  late Future<Map<String, dynamic>?> _statsFuture;

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz veritabanından anlık istatistikleri çek!
    _statsFuture = _dashboardService.getSystemStats();
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Güvenlik anahtarını imha et
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), // Derin YOTA Karanlığı
      appBar: AppBar(
        backgroundColor: const Color(0xFF131C2D),
        title: Row(
          children: [
            const Icon(Icons.dashboard_customize, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 12),
            const Text('YOTA MERKEZ İSTASYON', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 20),
              tooltip: 'Sistemden Çıkış Yap',
              onPressed: _logout,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_off, color: Colors.redAccent, size: 64),
                  SizedBox(height: 16),
                  Text('VERİTABANI BAĞLANTISI KOPTU', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            );
          }

          final stats = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SİSTEM TELEMETRİSİ (CANLI)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 2),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2, // Geniş ekranda 4'lü, dar ekranda 2'li yan yana
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.3,
                    children: [
                      _buildNeonStatCard('TOPLAM OTOBÜS', stats['total_buses'].toString(), Icons.directions_bus, Colors.blueAccent),
                      _buildNeonStatCard('AKTİF ROTA', stats['total_routes'].toString(), Icons.map, Colors.purpleAccent),
                      _buildNeonStatCard('PLANLI SEFER', stats['total_trips'].toString(), Icons.schedule, Colors.orangeAccent),
                      _buildNeonStatCard('KESİLEN BİLET', stats['active_tickets'].toString(), Icons.confirmation_number, Colors.greenAccent),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Neon Parlamalı Kurumsal Kart Tasarımı
  Widget _buildNeonStatCard(String title, String value, IconData icon, Color neonColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131C2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: neonColor.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(icon, size: 100, color: neonColor.withOpacity(0.05)), // Arka plan dev ikon efekti
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: neonColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: neonColor),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Courier'),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}