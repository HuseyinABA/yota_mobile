import 'package:flutter/material.dart';
import 'dart:async';
import 'trip_service.dart';

class OperationScreen extends StatefulWidget {
  const OperationScreen({super.key});

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  final TripService _tripService = TripService();
  
  bool _isRunning = false;
  double _progress = 0.0;
  int _speed = 0;
  int _distance = 240; 
  Timer? _timer;
  bool _isLoadingDb = true;

  final List<String> _liveLogs = [];
  List<Map<String, dynamic>> _passengers = [];

  @override
  void initState() {
    super.initState();
    _loadManifestFromDatabase(); 
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadManifestFromDatabase() async {
    _addLog('📡 SİSTEM: Veritabanına bağlanılıyor...');
    
    final dbData = await _tripService.getManifest(1); 
    
    if (dbData != null) {
      setState(() {
        _passengers = dbData.map<Map<String, dynamic>>((p) => {
          'name': p['passenger_name'] ?? 'Bilinmeyen Yolcu',
          'gender': p['gender'] ?? 'M', 
          'seat': p['seat_number'],
          'dropoff': p['dropoff_station'] ?? 'Son Durak',
          'boarded': false,
          'alighted': false
        }).toList();
        _isLoadingDb = false;
      });
      _addLog('✅ BAĞLANTI BAŞARILI: Veritabanından ${_passengers.length} yolcu çekildi.');
    } else {
      setState(() => _isLoadingDb = false);
      _addLog('❌ BAĞLANTI HATASI: Sunucuya ulaşılamadı veya sefer boş.');
    }
  }

  void _addLog(String message) {
    setState(() {
      _liveLogs.insert(0, "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')} - $message");
    });
  }

  void _toggleSimulation() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _speed = 0;
      });
      _addLog('⚠️ SİMÜLASYON DURDURULDU.');
    } else {
      setState(() {
        _isRunning = true;
        _speed = 95; 
      });
      _addLog('🚀 SİMÜLASYON BAŞLADI: Araç merkezden hareket ediyor.');
      
      if (_progress == 0.0) {
        for (var p in _passengers) {
          p['boarded'] = true;
        }
        _addLog('🎟️ BİNİŞ: Veritabanındaki tüm yolcular araca alındı.');
      }

      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _progress += 0.02; 
          _distance = (240 - (240 * _progress)).toInt();
          
          if (_progress < 0.95) {
             _speed = 90 + (DateTime.now().millisecond % 15);
          }

          if (_progress >= 1.0) {
            _progress = 1.0;
            _speed = 0;
            _distance = 0;
            timer.cancel();
            _isRunning = false;
            for (var p in _passengers) {
              p['alighted'] = true;
            }
            _addLog('🏁 VARIŞ: Son durak. Tüm yolcular indirildi.');
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF131C2D),
        title: Row(
          children: [
            const Icon(Icons.blur_on, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 12),
            const Text('YOTA VISION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: Colors.greenAccent)
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: _isLoadingDb ? Colors.orange : Colors.greenAccent, size: 10),
                  const SizedBox(width: 8),
                  Text(_isLoadingDb ? 'BAĞLANIYOR...' : 'DB AKTİF', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: 'Veritabanını Yenile',
            onPressed: () {
              setState(() => _isLoadingDb = true);
              _loadManifestFromDatabase();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTelemetryPanel(),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildRealisticCockpit()),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildLiveFeedPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131C2D), Color(0xFF1A2639)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.cyan.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('KALKIŞ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('VARIŞ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 8,
                width: MediaQuery.of(context).size.width * 0.9 * _progress,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricData('ANLIK HIZ', '$_speed', 'KM/S', Colors.cyanAccent),
              _buildMetricData('KALAN MESAFE', '$_distance', 'KM', Colors.orangeAccent),
              ElevatedButton.icon(
                onPressed: _isLoadingDb ? null : _toggleSimulation,
                icon: Icon(_isRunning ? Icons.stop_circle : Icons.play_circle_fill, color: Colors.white, size: 28),
                label: Text(_isRunning ? 'DURDUR' : 'SİSTEMİ BAŞLAT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.redAccent.withOpacity(0.8) : Colors.cyan.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 10,
                  shadowColor: _isRunning ? Colors.redAccent : Colors.cyanAccent,
                  disabledBackgroundColor: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricData(String title, String value, String unit, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 42, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
            const SizedBox(width: 6),
            Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        )
      ],
    );
  }

  Widget _buildRealisticCockpit() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.pinkAccent, 'KADIN'),
                const SizedBox(width: 24),
                _buildLegend(Colors.blueAccent, 'ERKEK'),
                const SizedBox(width: 24),
                _buildLegend(const Color(0xFF1E293B), 'BOŞ'),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_bus, color: Colors.white54, size: 32),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoadingDb 
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              itemCount: 13, 
              itemBuilder: (context, index) {
                if (index < 12) {
                  int baseSeat = index * 3 + 1; 
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSeat(baseSeat), 
                        const SizedBox(width: 60), 
                        _buildSeat(baseSeat + 1), 
                        const SizedBox(width: 12),
                        _buildSeat(baseSeat + 2), 
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSeat(37),
                        const SizedBox(width: 12),
                        _buildSeat(38),
                        const SizedBox(width: 12),
                        _buildSeat(39),
                        const SizedBox(width: 12),
                        _buildSeat(40),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeat(int seatNumber) {
    var passengerInfo = _passengers.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p!['seat'] == seatNumber && p['boarded'] == true && p['alighted'] == false, 
      orElse: () => null
    );

    Color seatColor = const Color(0xFF1E293B); 
    Color borderColor = Colors.white12;
    List<BoxShadow> glow = [];

    if (passengerInfo != null) {
      seatColor = passengerInfo['gender'] == 'F' ? Colors.pinkAccent.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.8);
      borderColor = passengerInfo['gender'] == 'F' ? Colors.pinkAccent : Colors.blueAccent;
      glow = [BoxShadow(color: seatColor.withOpacity(0.6), blurRadius: 12, spreadRadius: 1)];
    }

    // Tıklanabilir İskelet
    Widget seatWidget = InkWell(
      onTap: passengerInfo == null ? null : () => _showPassengerDetails(passengerInfo),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 55,
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: glow,
        ),
        child: Center(
          child: Text(
            seatNumber.toString(),
            style: TextStyle(
              color: passengerInfo != null ? Colors.white : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );

    // Eğer koltuk boşsa normal koltuğu döndür, doluysa MUHTEŞEM BİR HOVER (TOOLTIP) İÇİNE AL
    if (passengerInfo == null) return seatWidget;

    return Tooltip(
      message: '${passengerInfo['name']}\nVarış: ${passengerInfo['dropoff']}',
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95), // Koyu arka plan
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 10)],
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.5, letterSpacing: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      waitDuration: const Duration(milliseconds: 150), // Mouse gelince hemen açılsın
      child: seatWidget,
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16, height: 16, 
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24))
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  void _showPassengerDetails(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131C2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
        ),
        title: Row(
          children: [
            Icon(Icons.person, color: passenger['gender'] == 'F' ? Colors.pinkAccent : Colors.blueAccent),
            const SizedBox(width: 12),
            const Text('YOLCU BİLGİSİ', style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Ad Soyad:', passenger['name']),
            _buildDetailRow('Koltuk No:', passenger['seat'].toString()),
            _buildDetailRow('Varış:', passenger['dropoff']),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            const Text('OPERASYONEL EYLEMLER', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _addLog('🚨 MANUEL İŞLEM: ${passenger['name']} araçtan indirildi.');
                  setState(() => passenger['alighted'] = true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('YOLCU İNDİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.7)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('KAPAT', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLiveFeedPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: const Center(child: Text('OPERASYON LOGLARI', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _liveLogs.length,
              itemBuilder: (context, index) {
                String log = _liveLogs[index];
                Color logColor = Colors.white60;
                IconData icon = Icons.info_outline;

                if (log.contains('BİNİŞ') || log.contains('BAŞARILI')) { logColor = Colors.greenAccent; icon = Icons.check_circle; }
                else if (log.contains('İNİŞ') || log.contains('HATASI') || log.contains('MANUEL')) { logColor = Colors.redAccent; icon = Icons.error_outline; }
                else if (log.contains('SİSTEM')) { logColor = Colors.cyanAccent; icon = Icons.wifi; }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C2D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: logColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: logColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(log, style: TextStyle(color: logColor, fontSize: 13, height: 1.4))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}