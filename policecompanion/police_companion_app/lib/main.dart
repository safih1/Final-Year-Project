import 'package:flutter/material.dart';
import 'package:police_companion_app/screens/loginscreen.dart';

void main() {
  runApp(const PoliceResponseApp());
}

class PoliceResponseApp extends StatelessWidget {
  const PoliceResponseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Police Response System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1e40af),
        scaffoldBackgroundColor: const Color(0xFF0f172a),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3b82f6),
          secondary: const Color(0xFF60a5fa),
          surface: const Color(0xFF1e293b),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1e293b),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1e293b),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3b82f6), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF94a3b8)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3b82f6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// Login Screen

// Profile Dashboard
