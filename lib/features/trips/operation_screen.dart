import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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
  Timer? _dbRefreshTimer; 
  
  bool _isLoadingDb = true;
  bool _isOffline = false;

  // --- REVİZE EDİLEN BİLDİRİM SİSTEMİ DEĞİŞKENLERİ ---
  bool _isNewTicketAlertActive = false;
  int _previousPassengerCount = 0;

  final List<String> _liveLogs = [];
  List<Map<String, dynamic>> _passengers = [];

  @override
  void initState() {
    super.initState();
    _loadManifestFromDatabase(); 
    
    _dbRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isRunning) {
        _loadManifestFromDatabase();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dbRefreshTimer?.cancel(); 
    super.dispose();
  }

  Future<void> _loadManifestFromDatabase() async {
    if (_passengers.isEmpty && !_isOffline) {
       _addLog('📡 SİSTEM: Uydu bağlantısı aranıyor...');
    }
    
    try {
      final dbData = await _tripService.getManifest(1); 
      
      if (dbData != null) {
        if (!mounted) return;
        
        int currentCount = dbData.length;

        // VERİTABANINA YENİ BİRİ EKLENDİYSE ZARİF BİLDİRİMİ TETİKLE
        if (!_isLoadingDb && currentCount > _previousPassengerCount && _previousPassengerCount != 0) {
          _triggerNewTicketNotification();
        }
        
        setState(() {
          _passengers = dbData.map<Map<String, dynamic>>((p) => {
            'name': p['passenger_name'] ?? 'Bilinmeyen Yolcu',
            'gender': p['gender'] ?? 'M', 
            'seat': p['seat_number'],
            'dropoff': p['dropoff_station'] ?? 'Kastamonu',
            'boarded': _isRunning ? true : false, 
            'alighted': false
          }).toList();
          
          _previousPassengerCount = currentCount; 
          _isLoadingDb = false;
          
          if (_isOffline) {
            _isOffline = false;
            _addLog('🟢 BAĞLANTI GELDİ: Sistem tekrar çevrimiçi.');
          }
        });
      } else {
        _handleOfflineMode();
      }
    } catch (e) {
      _handleOfflineMode();
    }
  }

  // --- ZARİF VE POZİTİF YENİ BİLET BİLDİRİMİ ---
  void _triggerNewTicketNotification() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.lightImpact(); // Daha hafif, rahatsız etmeyen bir titreşim
    } catch (e) {
      debugPrint("Web Audio Policy engeli, görsel bildirim çalışacak.");
    }
    
    setState(() => _isNewTicketAlertActive = true);
    // Kırmızı ACİL yazısı yerine Mavi/Yeşil BİLGİ logu
    _addLog('🎫 BİLGİ: Merkezden yeni bir yolcu bileti sisteme onaylandı.');

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isNewTicketAlertActive = false);
      }
    });
  }

  void _handleOfflineMode() {
    if (!mounted) return;
    setState(() {
      _isLoadingDb = false;
      if (!_isOffline) {
        _isOffline = true;
        _addLog('🔴 BAĞLANTI KOPTU: Çevrimdışı (Offline) Moda Geçildi.');
      }
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
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
        if (!mounted) return;
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
            _showEndTripReport();
          }
        });
      });
    }
  }

  void _showEndTripReport() {
    int totalPassengers = _passengers.length;
    int femaleCount = _passengers.where((p) => p['gender'] == 'F').length;
    int maleCount = totalPassengers - femaleCount;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131C2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.cyanAccent, width: 2)),
        title: Column(
          children: [
            const Icon(Icons.verified, color: Colors.cyanAccent, size: 56),
            const SizedBox(height: 16),
            const Text('SEFER TAMAMLANDI', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('TR-1001 Numaralı Ankara-Kastamonu Rotalı Araç Hedefe Ulaştı.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            _buildReportRow('Toplam Yolcu:', '$totalPassengers Kişi', Icons.groups),
            _buildReportRow('Kadın / Erkek:', '$femaleCount / $maleCount', Icons.wc),
            _buildReportRow('Sistem Logları:', '${_liveLogs.length} Kayıt', Icons.receipt_long),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('📄 PDF MANİFESTO HAZIRLANIYOR VE İNDİRİLİYOR...', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      backgroundColor: const Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.greenAccent)),
                    )
                  );
                  _addLog('🖨️ RAPOR: Gün sonu PDF manifestosu başarıyla oluşturuldu.');
                },
                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF090E17)),
                label: const Text('PDF MANİFESTO ÇIKTISI AL', style: TextStyle(color: Color(0xFF090E17), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 10, shadowColor: Colors.cyanAccent.withOpacity(0.5)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, color: Colors.white38, size: 20), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14))]),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF131C2D),
        elevation: 5,
        shadowColor: Colors.cyanAccent.withOpacity(0.2),
        title: Row(
          children: [
            const Icon(Icons.blur_on, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 12),
            const Text('YOTA VISION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: _isOffline ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isOffline ? Colors.redAccent : Colors.greenAccent)),
              child: Row(
                children: [
                  Icon(_isOffline ? Icons.wifi_off : Icons.circle, color: _isOffline ? Colors.redAccent : (_isLoadingDb ? Colors.orange : Colors.greenAccent), size: 12),
                  const SizedBox(width: 8),
                  Text(_isOffline ? 'ÇEVRİMDİŞİ MOD' : (_isLoadingDb ? 'BAĞLANIYOR...' : 'SİSTEM AKTİF'), style: TextStyle(color: _isOffline ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            )
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent), tooltip: 'Ağı Yenile', onPressed: () { setState(() => _isLoadingDb = true); _loadManifestFromDatabase(); }),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTelemetryPanel(),
                const SizedBox(height: 24),
                SizedBox(
                  height: 480, 
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildRealisticCockpit()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildLiveFeedPanel()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildPassengerTable(),
                const SizedBox(height: 40), 
              ],
            ),
          ),
          
          // YENİ ZARİF BİLDİRİM TASARIMI
          if (_isNewTicketAlertActive)
            Positioned(
              top: 0, left: 0, right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.95), // Kırmızı yerine Turkuaz
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.confirmation_number, color: Color(0xFF090E17), size: 28),
                    SizedBox(width: 16),
                    Text('SİSTEM BİLDİRİMİ: MERKEZDEN YENİ BİLET ONAYLANDI', style: TextStyle(color: Color(0xFF090E17), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    SizedBox(width: 16),
                    Icon(Icons.check_circle_outline, color: Color(0xFF090E17), size: 28),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF131C2D), Color(0xFF1A2639)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isNewTicketAlertActive ? Colors.cyanAccent : Colors.cyan.withOpacity(0.2), width: _isNewTicketAlertActive ? 2 : 1), 
        boxShadow: [BoxShadow(color: _isNewTicketAlertActive ? Colors.cyanAccent.withOpacity(0.2) : Colors.cyan.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('ANKARA', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('ILGAZ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('KASTAMONU', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500), height: 8, width: MediaQuery.of(context).size.width * 0.9 * _progress,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricData('ANLIK HIZ', '$_speed', 'KM/S', Colors.cyanAccent),
              _buildMetricData('KALAN MESAFE', '$_distance', 'KM', Colors.orangeAccent),
              ElevatedButton.icon(
                onPressed: _isLoadingDb ? null : _toggleSimulation,
                icon: Icon(_isRunning ? Icons.stop_circle : Icons.play_circle_fill, color: Colors.white, size: 28),
                label: Text(_isRunning ? 'DURDUR' : 'SİSTEMİ BAŞLAT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: _isRunning ? Colors.redAccent.withOpacity(0.8) : Colors.cyan.withOpacity(0.8), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 10, shadowColor: _isRunning ? Colors.redAccent : Colors.cyanAccent, disabledBackgroundColor: Colors.grey.shade800),
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
          crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
          children: [Text(value, style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'Courier')), const SizedBox(width: 6), Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 16))],
        )
      ],
    );
  }

  Widget _buildRealisticCockpit() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 5)]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildLegend(Colors.pinkAccent, 'KADIN'), const SizedBox(width: 24), _buildLegend(Colors.blueAccent, 'ERKEK'), const SizedBox(width: 24), _buildLegend(const Color(0xFF1E293B), 'BOŞ')],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _isLoadingDb && _passengers.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              itemCount: 13, 
              itemBuilder: (context, index) {
                if (index < 12) {
                  int baseSeat = index * 3 + 1; 
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_buildSeat(baseSeat), const SizedBox(width: 50), _buildSeat(baseSeat + 1), const SizedBox(width: 12), _buildSeat(baseSeat + 2)],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_buildSeat(37), const SizedBox(width: 12), _buildSeat(38), const SizedBox(width: 12), _buildSeat(39), const SizedBox(width: 12), _buildSeat(40)],
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
    var passengerInfo = _passengers.cast<Map<String, dynamic>?>().firstWhere((p) => p!['seat'] == seatNumber && p['boarded'] == true && p['alighted'] == false, orElse: () => null);
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

  void _showWalkInTicketDialog(int seatNumber) {
    String selectedGender = 'M';
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131C2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.greenAccent.withOpacity(0.5))),
          title: Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.greenAccent),
              const SizedBox(width: 12),
              Text('KOLTUK $seatNumber - ELDEN BİLET', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yolcu Adı Soyadı',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.greenAccent), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('Erkek', style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: selectedGender == 'M',
                    selectedColor: Colors.blueAccent.withOpacity(0.5),
                    backgroundColor: Colors.white10,
                    onSelected: (val) => setDialogState(() => selectedGender = 'M'),
                  ),
                  ChoiceChip(
                    label: const Text('Kadın', style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: selectedGender == 'F',
                    selectedColor: Colors.pinkAccent.withOpacity(0.5),
                    backgroundColor: Colors.white10,
                    onSelected: (val) => setDialogState(() => selectedGender = 'F'),
                  ),
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _passengers.add({
                      'name': nameController.text.trim(),
                      'gender': selectedGender,
                      'seat': seatNumber,
                      'dropoff': 'Kastamonu',
                      'boarded': true,
                      'alighted': false
                    });
                    _previousPassengerCount++; 
                  });
                  _addLog('🎫 ELDEN BİLET: $seatNumber numaralı koltuğa ${nameController.text} eklendi.');
                  Navigator.pop(context);
                }
              },
              child: const Text('BİLETİ ONAYLA', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))]);
  }

  Widget _buildPassengerTable() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: const Text('YOLCU MANİFESTOSU VE BİLET DURUMU', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
          ),
          const Divider(height: 1, color: Colors.white10),
          _passengers.isEmpty
              ? const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text('Veritabanında kayıtlı yolcu bulunmuyor.', style: TextStyle(color: Colors.white54, fontSize: 16))))
              : SizedBox(
                  width: double.infinity, 
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.white.withOpacity(0.02)), headingTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2), dataTextStyle: const TextStyle(color: Colors.white, fontSize: 14), columnSpacing: 24, horizontalMargin: 24,
                    columns: const [DataColumn(label: Text('NO')), DataColumn(label: Text('PNR')), DataColumn(label: Text('AD SOYAD')), DataColumn(label: Text('CİNSİYET')), DataColumn(label: Text('KALKIŞ')), DataColumn(label: Text('VARIŞ')), DataColumn(label: Text('DURUM'))],
                    rows: _passengers.map((p) {
                      String pnr = 'TR-20${p['seat'].toString().padLeft(2, '0')}';
                      bool isFemale = p['gender'] == 'F';
                      return DataRow(
                        cells: [
                          DataCell(Text(p['seat'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          DataCell(Text(pnr, style: const TextStyle(color: Colors.white70, fontFamily: 'Courier'))),
                          DataCell(Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isFemale ? Colors.pinkAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: isFemale ? Colors.pinkAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5))), child: Text(isFemale ? 'Kadın' : 'Erkek', style: TextStyle(color: isFemale ? Colors.pinkAccent : Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)))),
                          const DataCell(Text('Ankara', style: TextStyle(color: Colors.white70))),
                          DataCell(Text(p['dropoff'], style: const TextStyle(color: Colors.white70))),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [Icon(p['alighted'] ? Icons.check_circle : Icons.event_seat, color: p['alighted'] ? Colors.redAccent : Colors.greenAccent, size: 18), const SizedBox(width: 8), Text(p['alighted'] ? 'İndi' : 'Araçta', style: TextStyle(color: p['alighted'] ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold))])),
                        ]
                      );
                    }).toList(),
                  ),
                ),
        ],
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
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { _addLog('🚨 MANUEL İŞLEM: ${passenger['name']} araçtan indirildi.'); setState(() => passenger['alighted'] = true); Navigator.pop(context); }, icon: const Icon(Icons.logout, color: Colors.white), label: const Text('YOLCU İNDİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.7), padding: const EdgeInsets.symmetric(vertical: 12)))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.cyanAccent)))],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)), const SizedBox(width: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]));
  }

  Widget _buildLiveFeedPanel() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent.withOpacity(0.15))),
      child: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: const Center(child: Text('OPERASYON LOGLARI', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _liveLogs.length,
              itemBuilder: (context, index) {
                String log = _liveLogs[index]; Color logColor = Colors.white60; IconData icon = Icons.info_outline;
                
                // Log renklendirme kurallarını güncelledik (BİLGİ ve BİLET eklendi)
                if (log.contains('BİNİŞ') || log.contains('BAŞARILI') || log.contains('GELDİ') || log.contains('BİLGİ')) { logColor = Colors.cyanAccent; icon = Icons.check_circle; }
                else if (log.contains('İNİŞ') || log.contains('HATASI') || log.contains('KOPTU') || log.contains('MANUEL') || log.contains('VARIŞ') || log.contains('ACİL')) { logColor = Colors.redAccent; icon = Icons.error_outline; }
                else if (log.contains('SİSTEM') || log.contains('RAPOR')) { logColor = Colors.cyanAccent; icon = Icons.wifi; }
                else if (log.contains('ELDEN BİLET')) { logColor = Colors.greenAccent; icon = Icons.point_of_sale; } // Elden Bilet artık yeşil

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF131C2D), borderRadius: BorderRadius.circular(12), border: Border.all(color: logColor.withOpacity(0.3))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: logColor, size: 20), const SizedBox(width: 12), Expanded(child: Text(log, style: TextStyle(color: logColor, fontSize: 13, height: 1.4)))]),
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