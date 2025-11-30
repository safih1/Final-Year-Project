import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background service (but don't start it yet)
  // It will be started after login
  
  runApp(const PoliceCompanionApp());
}

class PoliceCompanionApp extends StatelessWidget {
  const PoliceCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Police Companion',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
