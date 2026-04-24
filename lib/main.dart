import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YotaApp());
}

class YotaApp extends StatelessWidget {
  const YotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOTA Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E3A8A), 
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        textTheme: GoogleFonts.interTextTheme(), 
      ),
      home: const LoginScreen(),
    );
  }
}