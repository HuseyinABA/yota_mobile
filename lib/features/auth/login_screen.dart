import 'package:flutter/material.dart';
import '../../shared/main_layout.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // Servis duruyor ama sunum için bypass ettik
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    // SUNUM İÇİN BASİTLEŞTİRİLMİŞ GİRİŞ MANTIĞI (Backend bypass edildi)
    await Future.delayed(const Duration(seconds: 1)); // Loading animasyonu şık dursun diye
    
    bool success = ((email == 'admin' || email == 'muavin') && password == '123');

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      
      // MİMARİ KARAR: Giriş yapan kişiye göre yetki belirleme
      String role = email == 'muavin' ? 'MUAVIN' : 'ADMIN';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('KİMLİK DOĞRULANDI. YETKİ: $role', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
          backgroundColor: const Color(0xFF131C2D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.greenAccent)),
        ),
      );
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainLayout(userRole: role)));
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ERİŞİM REDDEDİLDİ. ID: admin/muavin, Şifre: 123 olmalı.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
          backgroundColor: const Color(0xFF131C2D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.redAccent)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17), 
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.all(40.0),
              constraints: const BoxConstraints(maxWidth: 450), 
              decoration: BoxDecoration(
                color: const Color(0xFF131C2D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 30, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 72, color: Colors.cyanAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'YOTA SECURE ACCESS',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Simülasyon Merkezi Kimlik Doğrulaması',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.cyanAccent),
                    decoration: InputDecoration(
                      labelText: 'SİSTEM ID',
                      labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                      prefixIcon: const Icon(Icons.fingerprint, color: Colors.cyanAccent),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.cyanAccent),
                    decoration: InputDecoration(
                      labelText: 'GÜVENLİK ANAHTARI',
                      labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyanAccent),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.9),
                        foregroundColor: const Color(0xFF090E17),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 10,
                        shadowColor: Colors.cyanAccent,
                      ),
                      child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Color(0xFF090E17), strokeWidth: 3))
                          : const Text('AĞA BAĞLAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}