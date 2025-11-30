import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  
  // Login
 Future<Map<String, dynamic>> login(String badgeNumber, String password) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/login/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'badge_number': badgeNumber,
      'password': password,
    }),
  );

  print("LOGIN RESPONSE: ${response.body}");
  print("STATUS CODE: ${response.statusCode}");

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setString('badge_number', badgeNumber);

    return data;
  } else {
    throw Exception('Login failed: ${response.body}');
  }
}

  
  // Register
Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/register/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(userData),
  );

  print("REGISTER RESPONSE: ${response.body}");
  print("STATUS CODE: ${response.statusCode}");

 if (response.statusCode == 200) {
  final data = jsonDecode(response.body);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', data['token']);
  await prefs.setString('badge_number', data['officer']['badge_number']); // Save badge number

  return data;
}
 else {
    throw Exception('Registration failed: ${response.body}');
  }
}

  
  // Get Officer Profile
  Future<Map<String, dynamic>> getProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    final response = await http.get(
      Uri.parse('$baseUrl/officers/me/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile');
    }
  }
  
  // Get Statistics
  Future<Map<String, dynamic>> getStatistics() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    final response = await http.get(
      Uri.parse('$baseUrl/officers/statistics/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load statistics');
    }
  }
  
  // Accept Emergency
  Future<Map<String, dynamic>> acceptEmergency(int emergencyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    final response = await http.post(
      Uri.parse('$baseUrl/emergencies/$emergencyId/accept_emergency/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to accept emergency');
    }
  }
  
  // Decline Emergency
  Future<void> declineEmergency(int emergencyId, String reason) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    final response = await http.post(
      Uri.parse('$baseUrl/emergencies/$emergencyId/decline_emergency/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'reason': reason}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to decline emergency');
    }
  }
}