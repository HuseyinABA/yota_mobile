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
    // Ekran açılır açılmaz verileri çekmeye başla
    _statsFuture = _dashboardService.getSystemStats();
  }

  // Güvenli Çıkış İşlemi
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Token'ı sil
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOTA Yönetici Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Güvenli Çıkış',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Veriler yüklenirken bir hata oluştu.', style: TextStyle(color: Colors.red)));
          }

          final stats = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistem Özeti',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2, // Ekrana göre kolon sayısı
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard('Toplam Otobüs', stats['total_buses'].toString(), Icons.directions_bus, Colors.blue),
                      _buildStatCard('Aktif Güzergâh', stats['total_routes'].toString(), Icons.map, Colors.orange),
                      _buildStatCard('Planlı Sefer', stats['total_trips'].toString(), Icons.schedule, Colors.purple),
                      _buildStatCard('Satılan Bilet', stats['active_tickets'].toString(), Icons.confirmation_number, Colors.green),
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

  // Kurumsal İstatistik Kartı Tasarımı
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}