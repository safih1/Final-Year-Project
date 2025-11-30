import 'package:flutter/material.dart';
import 'package:secure_step/screens/high_risk_zones_screen.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/detection_screen.dart';

class SecureStepApp extends StatefulWidget {
  const SecureStepApp({super.key});

  @override
  State<SecureStepApp> createState() => _SecureStepAppState();
}

class _SecureStepAppState extends State<SecureStepApp> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _loggedInUser;
  List<Map<String, dynamic>> _emergencyContacts = [];

  void _setLoggedInUser(Map<String, dynamic>? user) {
    setState(() {
      _loggedInUser = user;
    });
    if (user != null) {
      _loadEmergencyContacts();
    }
  }

  void _loadEmergencyContacts() async {
    try {
      final contacts = await _apiService.getEmergencyContacts();
      setState(() {
        _emergencyContacts = contacts.cast<Map<String, dynamic>>();
        if (_loggedInUser != null) {
          // Store the full contact data (not just name/phone)
          _loggedInUser!['emergencyContacts'] = _emergencyContacts;
        }
      });
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  void _updateUserEmergencyContacts(String userEmail, Map<String, String> newContact) async {
    try {
      final result = await _apiService.addEmergencyContact(newContact);
      if (result['id'] != null) {
        _loadEmergencyContacts(); // Refresh contacts
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add contact: $e')),
      );
    }
  }

  void _updateUserEmergencyData(String userEmail, String newLocation) async {
    try {
      final result = await _apiService.triggerEmergency(
        alertType: 'manual',
        address: newLocation,
        description: 'Manual emergency trigger',
      );

      if (result['alert'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency alert sent successfully!')),
        );
        // Update emergency count in logged in user
        if (_loggedInUser != null) {
          setState(() {
            _loggedInUser!['emergency_count'] = (_loggedInUser!['emergency_count'] ?? 0) + 1;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send emergency alert: $e')),
      );
    }
  }

  void _updateUserProfile(Map<String, dynamic> updatedUserDetails) async {
    // This method would call the API to update profile
    // For now, we'll update the local user data
    setState(() {
      if (_loggedInUser != null) {
        _loggedInUser = {..._loggedInUser!, ...updatedUserDetails};
      }
    });
  }

  // ADDED: Missing logout method
  void _logout() {
    setState(() {
      _loggedInUser = null;
      _emergencyContacts = [];
    });
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureStep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1419),
        primaryColor: const Color(0xFF6B48FF),
        hintColor: const Color(0xFF6B48FF),
        cardColor: const Color(0xFF1E2A3B),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF1E2A3B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.white70, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
          labelLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: const Color(0xFF6B48FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B48FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2E3E5C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6B48FF), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF6B48FF);
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF6B48FF).withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.5);
          }),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const SplashScreen());
        }
        else if (settings.name == '/emergency_contacts') {
          return MaterialPageRoute(
            builder: (context) => const EmergencyContactsScreen(),
          );
        }
        else if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => LoginScreen(
              onLoginSuccess: _setLoggedInUser,
            ),
          );
        } else if (settings.name == '/register') {
          return MaterialPageRoute(
            builder: (context) => const RegistrationScreen(),
          );
        } else if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => HomeScreen(
              loggedInUser: _loggedInUser,
              onUpdateEmergencyContacts: _updateUserEmergencyContacts,
              onUpdateEmergencyData: _updateUserEmergencyData,
              onLogout: _logout,
            ),
          );
        } else if (settings.name == '/settings') {
          return MaterialPageRoute(
            builder: (context) => SettingsScreen(
              loggedInUser: _loggedInUser,
              onLogout: _logout,
            ),
          );
        }
        else if (settings.name == '/high_risk_zones') {
          return MaterialPageRoute(
            builder: (context) => const HighRiskZonesScreen(),
          );
        }
        else if (settings.name == '/profile') {
          if (_loggedInUser != null) {
            return MaterialPageRoute(
              builder: (context) => ProfileScreen(
                loggedInUser: Map<String, dynamic>.from(_loggedInUser!),
                onUpdateProfile: _updateUserProfile,
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (context) => LoginScreen(
                onLoginSuccess: _setLoggedInUser,
              ),
            );
          }
        } else if (settings.name == '/admin_login') {
          return MaterialPageRoute(
            builder: (context) => AdminLoginScreen(
              adminUsers: const [], // Empty for now
              onAdminLoginSuccess: _setLoggedInUser,
            ),
          );
        } else if (settings.name == '/admin_panel') {
          // In the '/admin_panel' route:
          return MaterialPageRoute(
            builder: (context) => AdminPanelScreen(
              onLogout: _logout,
            ),
          );
        } else if (settings.name == '/detection') {
          return MaterialPageRoute(
            builder: (context) => const DetectionScreen(),
          );
        }
        return null;
      },
    );
  }
}