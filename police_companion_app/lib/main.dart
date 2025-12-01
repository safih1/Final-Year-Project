import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/location_background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // VERY IMPORTANT: initialize background service
  await LocationBackgroundService.initialize();

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
