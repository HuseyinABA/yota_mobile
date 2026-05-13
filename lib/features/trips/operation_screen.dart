import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'trip_service.dart';

class OperationScreen extends StatefulWidget {
  const OperationScreen({super.key});

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  final TripService _tripService = TripService();
  
  // --- MİMARİ: SEKMELER VE ROTA ---
  int _selectedMenuIndex = 0; 
  String _selectedRoute = 'Ankara-Ilgaz-Kastamonu';
  final List<String> _routes = ['Ankara-Ilgaz-Kastamonu', 'Samsun-Bafra', 'Adana-Ceyhan-Osmaniye', 'İzmir-Aydın-Denizli'];
  
  // --- SİMÜLASYON ---
  bool _isRunning = false;
  double _progress = 0.0;
  int _speed = 0;
  int _distance = 240; 
  Timer? _timer;
  
  bool _isLoadingDb = true;
  bool _isOffline = false;
  bool _isNewTicketAlertActive = false;
  
  bool _hasStoppedAtMidpoint = false; 
  int _pauseTicks = 0;

  final List<Map<String, dynamic>> _liveLogs = [];
  List<Map<String, dynamic>> _passengers = [];

  @override
  void initState() {
    super.initState();
    _loadDataForRoute(_selectedRoute); 
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // BUG 2 ÇÖZÜMÜ: ROTA DEĞİŞTİĞİNDE VERİLERİ DİNAMİK YENİLEME
  Future<void> _loadDataForRoute(String route) async {
    setState(() => _isLoadingDb = true);
    
    // Eğer ilk rotaysa API'yi dene, değilse sunum şovu için dinamik veri üret
    if (route == 'Ankara-Ilgaz-Kastamonu') {
      try {
        final dbData = await _tripService.getManifest(1); 
        if (dbData != null && dbData.isNotEmpty) {
          _mapApiDataToPassengers(dbData, route);
          return;
        }
      } catch (e) {
        debugPrint("API Hatası: $e");
      }
    }
    
    // API başarısız olursa veya başka rota seçilirse Mock(Sahte) veri üret (Sunum Kurtarıcı)
    _generateMockData(route);
  }

  void _mapApiDataToPassengers(List<dynamic> dbData, String route) {
    if (!mounted) return;
    List<String> stops = route.split('-');
    
    setState(() {
      _passengers = dbData.map<Map<String, dynamic>>((p) {
        String passengerName = p['passenger_name'] ?? 'Bilinmeyen Yolcu';
        String genderVal = p['gender']?.toString().toUpperCase() ?? 'M';
        String upperName = passengerName.toUpperCase();
        if (genderVal == 'M' && (upperName.contains('AYŞE') || upperName.contains('FATMA') || upperName.contains('DİLARA') || upperName.contains('ZEYNEP') || upperName.contains('ELİF') || upperName.contains('ESRA') || upperName.contains('GİZEM') || upperName.contains('CEREN') || upperName.contains('DENİZ') || upperName.contains('BÜŞRA'))) {
            genderVal = 'F';
        }
        int seatNo = p['seat_number'] ?? 0;
        String dropoffVal = p['dropoff_station'] ?? stops.last;
        if (stops.length > 2 && (seatNo == 3 || seatNo == 9 || seatNo == 15 || seatNo == 24)) {
            dropoffVal = stops[1];
        }

        return {
          'name': passengerName,
          'gender': genderVal, 
          'seat': seatNo,
          'boarding': stops.first, // BUG 3 ÇÖZÜMÜ: Kalkış noktası rotaya göre dinamik
          'dropoff': dropoffVal,
          'age': 18 + (seatNo % 40), 
          'price': 350.0 + (seatNo * 2), 
          'boarded': _isRunning || _progress > 0 ? true : false, 
          'alighted': false
        };
      }).toList();
      _isLoadingDb = false;
      _isOffline = false;
    });
  }

  void _generateMockData(String route) {
    if (!mounted) return;
    List<String> stops = route.split('-');
    int passengerCount = route == 'Samsun-Bafra' ? 14 : 25 + Random().nextInt(10);
    List<String> names = ['Ahmet Yılmaz', 'Ayşe Demir', 'Mehmet Kaya', 'Fatma Şahin', 'Ali Çelik', 'Zeynep Yıldız', 'Mustafa Öz', 'Elif Doğan', 'Emre Can', 'Dilara Kudret', 'Okan Aslan', 'Esra Polat', 'Caner Koç', 'Gizem Kurt'];
    
    List<Map<String, dynamic>> newPassengers = [];
    for (int i = 0; i < passengerCount; i++) {
      int seatNo = i + 1;
      if (seatNo > 40) break;
      String name = names[i % names.length];
      bool isFemale = ['Ayşe', 'Fatma', 'Zeynep', 'Elif', 'Dilara', 'Esra', 'Gizem'].any((n) => name.contains(n));
      String dropoff = (stops.length > 2 && i % 4 == 0) ? stops[1] : stops.last;
      
      newPassengers.add({
        'name': name,
        'gender': isFemale ? 'F' : 'M',
        'seat': seatNo,
        'boarding': stops.first,
        'dropoff': dropoff,
        'age': 18 + Random().nextInt(50),
        'price': 200.0 + Random().nextInt(300),
        'boarded': _isRunning || _progress > 0 ? true : false,
        'alighted': false
      });
    }

    setState(() {
      _passengers = newPassengers;
      _isLoadingDb = false;
    });
  }

  void _addLog(String type, String message, String title, String? passengerDetail, Color color) {
    if (!mounted) return;
    setState(() {
      _liveLogs.insert(0, {
        "time": "${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}",
        "type": type, "title": title, "message": message, "passenger": passengerDetail, "color": color
      });
    });
  }

  void _changeRoute(String route) {
    setState(() {
      _selectedRoute = route;
      List<String> stops = route.split('-');
      _distance = stops.length == 2 ? 50 : 240;
      _progress = 0.0; _speed = 0; _isRunning = false;
      _timer?.cancel();
      _liveLogs.clear();
      _hasStoppedAtMidpoint = false; _pauseTicks = 0;
    });
    _loadDataForRoute(route); // YENİ ROTANIN YOLCULARINI VE CİROSUNU GETİR
    _addLog('SİSTEM', 'Rota değiştirildi: $route', 'BİLGİ', null, Colors.cyanAccent);
  }

  void _toggleSimulation() {
    List<String> stops = _selectedRoute.split('-');
    if (_isRunning) {
      _timer?.cancel();
      setState(() { _isRunning = false; _speed = 0; _pauseTicks = 0; });
      _addLog('OPERASYON', 'Simülasyon durduruldu.', 'DURAKLATILDI', null, Colors.orangeAccent);
    } else {
      if (_progress >= 1.0) {
          setState(() {
            _progress = 0.0; _distance = stops.length == 2 ? 50 : 240;
            _hasStoppedAtMidpoint = false; _pauseTicks = 0;
            for (var p in _passengers) { p['alighted'] = false; p['boarded'] = false; }
          });
      }

      setState(() { _isRunning = true; _speed = stops.length == 2 ? 60 : 95; });
      
      if (_progress == 0.0) {
        _addLog('OPERASYON', 'Araç ${stops.first} merkezden hareket ediyor.', 'HAREKET', null, Colors.cyanAccent);
        int binen = 0;
        for (var p in _passengers) { p['boarded'] = true; binen++; }
        _addLog('BİNİŞ', 'YENİ YOLCU: $binen kişi biniyor.', '${stops.first.toUpperCase()} - BİNİŞ', null, Colors.greenAccent);
      }

      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted) return;
        setState(() {
          if (_pauseTicks > 0) {
              _pauseTicks--;
              if (_pauseTicks == 0) {
                  _addLog('OPERASYON', 'Mola bitti, yola çıkıldı.', 'HAREKET', null, Colors.cyanAccent);
                  _speed = stops.length == 2 ? 60 : 95;
              }
              return; 
          }

          _progress += 0.02; 
          int maxDist = stops.length == 2 ? 50 : 240;
          _distance = (maxDist - (maxDist * _progress)).toInt();
          if (_progress < 0.95) _speed = (stops.length == 2 ? 60 : 90) + (DateTime.now().millisecond % 15);

          // ARA DURAK MANTIĞI
          if (stops.length > 2 && _progress >= 0.50 && !_hasStoppedAtMidpoint) {
             _hasStoppedAtMidpoint = true; _speed = 0; _pauseTicks = 8; 
             int alightCount = 0;
             String midStop = stops[1];
             for (var p in _passengers) {
                 if (p['dropoff'] == midStop) { p['alighted'] = true; alightCount++; }
             }
             if(alightCount > 0) _addLog('İNİŞ', 'DİKKAT: $alightCount yolcu iniyor.', '${midStop.toUpperCase()} - İNİŞ', null, Colors.redAccent);
             return; 
          }

          // SON DURAK MANTIĞI
          if (_progress >= 1.0) {
            _progress = 1.0; _speed = 0; _distance = 0; timer.cancel(); _isRunning = false;
            int alightCount = 0;
            for (var p in _passengers) {
              if (!p['alighted']) { p['alighted'] = true; alightCount++; }
            }
            _addLog('İNİŞ', 'DİKKAT: $alightCount yolcu iniyor.', '${stops.last.toUpperCase()} - İNİŞ', null, Colors.redAccent);
            _showEndTripReport();
          }
        });
      });
    }
  }

  void _showEndTripReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131C2D),
        title: const Text('SEFER TAMAMLANDI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Araç son durağa ulaştı. Operasyon kapatılıyor.', style: TextStyle(color: Colors.white54)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.cyanAccent)))],
      ),
    );
  }

  // ==========================================
  // WIDGET'LAR VE GÖRSEL BİLEŞENLER
  // ==========================================
  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))
      ]
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)), const SizedBox(width: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildMetricData(String title, String value, String unit, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
          children: [Text(value, style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'Courier')), const SizedBox(width: 6), Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 16))]
        )
      ],
    );
  }

  // BUG 1 ÇÖZÜMÜ: KUSURSUZ 2+1 KOLTUK DİZİLİMİ MİMARİSİ
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
      glow = [BoxShadow(color: seatColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)];
    }

    Widget seatWidget = InkWell(
      onTap: passengerInfo == null ? () => _showWalkInTicketDialog(seatNumber) : () => _showPassengerDetails(passengerInfo),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48, height: 52,
        decoration: BoxDecoration(color: seatColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor, width: 1.5), boxShadow: glow),
        child: Center(child: Text(seatNumber.toString(), style: TextStyle(color: passengerInfo != null ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 16))),
      ),
    );

    if (passengerInfo == null) {
      return Tooltip(message: 'Koltuk Boş\nBilet Kesmek İçin Tıkla', child: seatWidget, decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.greenAccent.withOpacity(0.5))));
    }

    return Tooltip(message: '${passengerInfo['name']}\nVarış: ${passengerInfo['dropoff']}', decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.95), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5))), textStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: seatWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), 
      body: Column(
        children: [
          _buildTopBar(), 
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(), 
                Expanded(child: Container(color: const Color(0xFF0B111D), child: _buildCurrentView()))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: const Color(0xFF131C2D), border: Border(bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.1)))),
      child: Row(
        children: [
          const Icon(Icons.blur_on, color: Colors.cyanAccent, size: 32), const SizedBox(width: 12),
          const Text('YOTA VISION', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          const SizedBox(width: 60),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF090E17), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.cyanAccent, size: 16), const SizedBox(width: 8),
                const Text('SEFER SEÇİMİ: ', style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF131C2D), value: _selectedRoute, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    onChanged: (String? newValue) { if (newValue != null) _changeRoute(newValue); },
                    items: _routes.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _isOffline ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isOffline ? Colors.redAccent : Colors.greenAccent)),
            child: Row(
              children: [
                Icon(_isOffline ? Icons.wifi_off : Icons.circle, color: _isOffline ? Colors.redAccent : (_isLoadingDb ? Colors.orange : Colors.greenAccent), size: 12), const SizedBox(width: 8),
                Text(_isOffline ? 'ÇEVRİMDİŞİ' : (_isLoadingDb ? 'GÜNCELLENİYOR...' : 'SİSTEM AKTİF'), style: TextStyle(color: _isOffline ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250, decoration: BoxDecoration(color: const Color(0xFF131C2D), border: Border(right: BorderSide(color: Colors.cyanAccent.withOpacity(0.1)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildSidebarItem(0, Icons.dashboard, 'Genel'),
          _buildSidebarItem(1, Icons.sensors, 'Simülasyon'),
          _buildSidebarItem(2, Icons.airline_seat_recline_extra, 'Kokpit'),
          _buildSidebarItem(3, Icons.list_alt, 'Yolcu Listesi'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    bool isSelected = _selectedMenuIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedMenuIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: isSelected ? Colors.cyanAccent.withOpacity(0.05) : Colors.transparent, border: Border(left: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.transparent, width: 4))),
        child: Row(children: [Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white54, size: 22), const SizedBox(width: 16), Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16, letterSpacing: 1))]),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedMenuIndex) {
      case 0: return _buildDashboardView();
      case 1: return _buildOperationView();
      case 2: return _buildCockpitView();
      case 3: return _buildListView();
      default: return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    double totalCiro = _passengers.fold(0, (sum, item) => sum + (item['price'] as double));
    int totalP = _passengers.length;
    double doluluk = (totalP / 40) * 100;
    int maleC = _passengers.where((p) => p['gender'] == 'M').length;
    int femaleC = totalP - maleC;
    int dist = _selectedRoute.split('-').length == 2 ? 50 : 240;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SİSTEM ÖZETİ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDashCard('TOPLAM CİRO', '${totalCiro.toInt()} ₺', Icons.account_balance_wallet, Colors.greenAccent)), const SizedBox(width: 16),
              Expanded(child: _buildDashCard('YOLCU SAYISI', '$totalP', Icons.groups, Colors.blueAccent)), const SizedBox(width: 16),
              Expanded(child: _buildDashCard('DOLULUK', '%${doluluk.toInt()}', Icons.percent, Colors.pinkAccent)), const SizedBox(width: 16),
              Expanded(child: _buildDashCard('ROTA', '$dist KM', Icons.route, Colors.orangeAccent)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 250, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CİNSİYET DAĞILIMI', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Center(child: SizedBox(width: 120, height: 120, child: CustomPaint(painter: DonutChartPainter(maleC, femaleC)))),
                      const Spacer(),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildLegend(Colors.blueAccent, 'Erkek ($maleC)'), const SizedBox(width: 16), _buildLegend(Colors.pinkAccent, 'Kadın ($femaleC)')])
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Container(
                  height: 250, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YAŞ ANALİZİ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBarChartCol('18-25', _passengers.where((p) => p['age'] <= 25).length, totalP),
                            _buildBarChartCol('26-40', _passengers.where((p) => p['age'] > 25 && p['age'] <= 40).length, totalP),
                            _buildBarChartCol('41-60', _passengers.where((p) => p['age'] > 40 && p['age'] <= 60).length, totalP),
                            _buildBarChartCol('60+', _passengers.where((p) => p['age'] > 60).length, totalP),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  height: 250, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.info_outline, color: Colors.cyanAccent), SizedBox(width: 8), Text('BİLGİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                      const Divider(color: Colors.white10, height: 32),
                      _buildDetailRow('Kaptan:', 'Hüseyin Aksoy'), _buildDetailRow('Muavin:', 'Burak Çetin'),
                      _buildDetailRow('Marka:', 'Setra 516 HD'), _buildDetailRow('Plaka:', '31 HTY 25'),
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDashCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)), Icon(icon, color: Colors.white24)]),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBarChartCol(String label, int count, int total) {
    double pct = total == 0 ? 0 : count / total;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(count.toString(), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Container(width: 40, height: 120 * pct, decoration: const BoxDecoration(color: Colors.deepPurpleAccent, borderRadius: BorderRadius.vertical(top: Radius.circular(4)))), const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildOperationView() {
    List<String> routeStops = _selectedRoute.split('-');
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                // BUG 3 ÇÖZÜMÜ: Ekranda rotadaki TÜM DURAKLARI göster
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: routeStops.map((s) => Text(s.toUpperCase(), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5))).toList(),
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500), height: 8, 
                      width: MediaQuery.of(context).size.width * 0.6 * _progress,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)]),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetricData('ANLIK HIZ', '$_speed', 'KM/S', Colors.cyanAccent),
                    _buildMetricData('KALAN MESAFE', '$_distance', 'KM', Colors.orangeAccent),
                    ElevatedButton.icon(
                      onPressed: _isLoadingDb ? null : _toggleSimulation,
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: const Color(0xFF090E17)),
                      label: Text(_isRunning ? 'DURAKLAT' : 'BAŞLAT', style: const TextStyle(color: Color(0xFF090E17), fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _liveLogs.length,
              itemBuilder: (context, index) {
                var log = _liveLogs[index];
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 400, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(12), border: Border.all(color: log['color'].withOpacity(0.3)), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 4, height: 40, decoration: BoxDecoration(color: log['color'], borderRadius: BorderRadius.circular(2))), const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.arrow_circle_right_outlined, color: log['color'], size: 16), const SizedBox(width: 8),
                                  Text(log['title'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)), const Spacer(),
                                  Text(log['time'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 8), Text(log['message'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              if (log['passenger'] != null) ...[
                                const SizedBox(height: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: log['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('👤 ${log['passenger']}', style: TextStyle(color: log['color'], fontSize: 11, fontWeight: FontWeight.bold)))
                              ]
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCockpitView() {
    return Center(
      child: Container(
        width: 400, margin: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(24.0), child: Text('KOKPİT (2+1)', style: TextStyle(color: Colors.white38, letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.bold))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildLegend(Colors.pinkAccent, 'KADIN'), const SizedBox(width: 24), _buildLegend(Colors.blueAccent, 'ERKEK'), const SizedBox(width: 24), _buildLegend(const Color(0xFF1E293B), 'BOŞ')]),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                itemCount: 13, 
                itemBuilder: (context, index) {
                  // BUG 1 ÇÖZÜMÜ: Kusursuz 2+1 yerleşim: Sol(Tekli) - KORİDOR - Sağ(Çiftli)
                  if (index < 12) {
                    int baseSeat = index * 3 + 1; 
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0), 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          _buildSeat(baseSeat), // 1 NUMARA
                          const SizedBox(width: 40), // KORİDOR (GENİŞ)
                          _buildSeat(baseSeat + 1), // 2 NUMARA
                          const SizedBox(width: 8), // ÇİFTLİ KOLTUK ARASI (DAR)
                          _buildSeat(baseSeat + 2)  // 3 NUMARA
                        ]
                      )
                    );
                  } else {
                    // SON SIRA 4'LÜ KOLTUK
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0), 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          _buildSeat(37), const SizedBox(width: 8),
                          _buildSeat(38), const SizedBox(width: 8),
                          _buildSeat(39), const SizedBox(width: 8), 
                          _buildSeat(40)
                        ]
                      )
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: const Text('YOLCU MANİFESTOSU VE BİLET DURUMU', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
            ),
            _isLoadingDb ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent))) :
            _passengers.isEmpty
                ? const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text('Veritabanında kayıtlı yolcu bulunmuyor.', style: TextStyle(color: Colors.white54, fontSize: 16))))
                : DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.white.withOpacity(0.02)), headingTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold), dataTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
                    columns: const [DataColumn(label: Text('NO')), DataColumn(label: Text('PNR')), DataColumn(label: Text('AD SOYAD')), DataColumn(label: Text('CİNSİYET')), DataColumn(label: Text('KALKIŞ')), DataColumn(label: Text('VARIŞ')), DataColumn(label: Text('DURUM'))],
                    rows: _passengers.map((p) {
                      bool isFemale = p['gender'] == 'F';
                      return DataRow(
                        cells: [
                          DataCell(Text(p['seat'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('TR-20${p['seat'].toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(p['name'])),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isFemale ? Colors.pinkAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: isFemale ? Colors.pinkAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5))), child: Text(isFemale ? 'Kadın' : 'Erkek', style: TextStyle(color: isFemale ? Colors.pinkAccent : Colors.blueAccent, fontSize: 12)))),
                          DataCell(Text(p['boarding'] ?? 'Bilinmiyor', style: const TextStyle(color: Colors.white70))), // BUG 3 ÇÖZÜMÜ: Dinamik Kalkış
                          DataCell(Text(p['dropoff'], style: const TextStyle(color: Colors.white70))), // Dinamik Varış
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [Icon(p['alighted'] ? Icons.check_circle : Icons.event_seat, color: p['alighted'] ? Colors.redAccent : Colors.greenAccent, size: 16), const SizedBox(width: 8), Text(p['alighted'] ? 'İndi' : 'Araçta', style: TextStyle(color: p['alighted'] ? Colors.redAccent : Colors.greenAccent))])),
                        ]
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  void _showWalkInTicketDialog(int seatNumber) {
    String selectedGender = 'M';
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131C2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.greenAccent.withOpacity(0.5))),
          title: Text('KOLTUK $seatNumber - ELDEN BİLET', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Yolcu Adı Soyadı', labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(label: const Text('Erkek', style: TextStyle(color: Colors.white)), selected: selectedGender == 'M', selectedColor: Colors.blueAccent.withOpacity(0.5), backgroundColor: Colors.white10, onSelected: (val) => setDialogState(() => selectedGender = 'M')),
                  ChoiceChip(label: const Text('Kadın', style: TextStyle(color: Colors.white)), selected: selectedGender == 'F', selectedColor: Colors.pinkAccent.withOpacity(0.5), backgroundColor: Colors.white10, onSelected: (val) => setDialogState(() => selectedGender = 'F')),
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _passengers.add({ 'name': nameController.text.trim(), 'gender': selectedGender, 'seat': seatNumber, 'boarding': _selectedRoute.split('-').first, 'dropoff': _selectedRoute.split('-').last, 'age': 30, 'price': 350.0, 'boarded': true, 'alighted': false });
                  });
                  _addLog('BİNİŞ', 'YENİ YOLCU: 1 kişi biniyor.', 'ARA DURAK - BİNİŞ', '$seatNumber: ${nameController.text.trim()}', Colors.yellowAccent);
                  Navigator.pop(context);
                }
              },
              child: const Text('ONAYLA', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _showPassengerDetails(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131C2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
        title: Row(children: [Icon(Icons.person, color: passenger['gender'] == 'F' ? Colors.pinkAccent : Colors.blueAccent), const SizedBox(width: 12), const Text('YOLCU BİLGİSİ', style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.bold))]),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Ad Soyad:', passenger['name']), _buildDetailRow('Koltuk No:', passenger['seat'].toString()), _buildDetailRow('Varış:', passenger['dropoff']), const SizedBox(height: 20), const Divider(color: Colors.white10), const SizedBox(height: 10), const Text('OPERASYONEL EYLEMLER', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { _addLog('İNİŞ', 'MANUEL İŞLEM: ${passenger['name']} araçtan indirildi.', 'YOLCU İNDİRİLDİ', null, Colors.redAccent); setState(() => passenger['alighted'] = true); Navigator.pop(context); }, icon: const Icon(Icons.logout, color: Colors.white), label: const Text('YOLCU İNDİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.7), padding: const EdgeInsets.symmetric(vertical: 12)))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.cyanAccent)))],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final int maleCount;
  final int femaleCount;
  DonutChartPainter(this.maleCount, this.femaleCount);

  @override
  void paint(Canvas canvas, Size size) {
    double total = (maleCount + femaleCount).toDouble();
    if (total == 0) return;
    double maleAngle = (maleCount / total) * 2 * pi;
    double femaleAngle = (femaleCount / total) * 2 * pi;

    Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 30;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    paint.color = Colors.blueAccent;
    canvas.drawArc(rect, -pi / 2, maleAngle, false, paint);
    paint.color = Colors.pinkAccent;
    canvas.drawArc(rect, -pi / 2 + maleAngle, femaleAngle, false, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}