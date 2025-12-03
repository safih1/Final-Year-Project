import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  // TOKEN MANAGEMENT
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ✅ DEBUG TOKEN METHOD
  Future<void> debugToken() async {
    final token = await getToken();
    print('🔑 Current Token: ${token ?? "No token found"}');
  }

  // ==============================
  // AUTH
  // ==============================
  
  Future<Map<String, dynamic>> register(Map<String, String> userData) async {
    try {
      final requestData = {
        'email': userData['email'],
        'username': userData['email']!.split('@')[0],
        'full_name': userData['fullName'],
        'password': userData['password'],
        'confirm_password': userData['password'],
        'phone_number': userData['phone_number'] ?? ''
      };

      print('=== FLUTTER DEBUG ===');
      print('URL: ${ApiConfig.registerUrl}');
      print('Body: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          return {'error': errorData.toString()};
        } catch (e) {
          return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
        }
      }
    } catch (e) {
      print('Network error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['tokens'] != null) {
        await storeToken(data['tokens']['access']);
      }

      return data;
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // ==============================
  // EMERGENCY TRIGGER
  // ==============================

  Future<Map<String, dynamic>> triggerEmergency({
  required String alertType,
  double? latitude,
  double? longitude,
  String? address,
  String? description,
}) async {
  try {
    // Build payload dynamically - only include non-null values
    final Map<String, dynamic> payload = {
      'alert_type': alertType.toLowerCase(),
    };
    
    // Only add fields if they have values
    if (latitude != null) {
      payload['location_latitude'] = latitude;
    }
    
    if (longitude != null) {
      payload['location_longitude'] = longitude;
    }
    
    if (address != null && address.isNotEmpty) {
      payload['location_address'] = address;
    }
    
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }
    
    print('🔥 Triggering Emergency');
    print('📤 URL: ${ApiConfig.emergencyTriggerUrl}');
    print('📤 Payload: $payload');
    
    final headers = await getHeaders();
    print('📤 Headers: $headers');
    
    final response = await http.post(
      Uri.parse(ApiConfig.emergencyTriggerUrl),
      headers: headers,
      body: json.encode(payload),
    );

    print('📥 Response Status: ${response.statusCode}');
    print('📥 Response Body: ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'error': 'HTTP ${response.statusCode}',
        'details': response.body
      };
    }
  } catch (e) {
    print('❌ triggerEmergency Error: $e');
    return {'error': 'Network error: $e'};
  }
}

  // ==============================
  // ✅ EMERGENCY CONTACTS CRUD
  // ==============================

  Future<List<dynamic>> getEmergencyContacts() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.emergencyContactsUrl),
        headers: await getHeaders(),
      );

      print('📥 Get Contacts Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as List;
      } else {
        throw Exception('Failed to load contacts: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting contacts: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addEmergencyContact(Map<String, String> contactData) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.emergencyContactsUrl),
        headers: await getHeaders(),
        body: json.encode(contactData),
      );

      print('📤 Add Contact Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': 'Failed to add contact: ${response.body}'};
      }
    } catch (e) {
      print('❌ Error adding contact: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateEmergencyContact(int contactId, Map<String, String> contactData) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.emergencyContactsUrl}$contactId/'),
        headers: await getHeaders(),
        body: json.encode(contactData),
      );

      print('📝 Update Contact Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': 'Failed to update contact: ${response.body}'};
      }
    } catch (e) {
      print('❌ Error updating contact: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.emergencyContactsUrl}$contactId/'),
        headers: await getHeaders(),
      );

      print('🗑️ Delete Contact Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true, 'message': 'Contact deleted successfully'};
      } else {
        return {'error': 'Failed to delete contact: ${response.body}'};
      }
    } catch (e) {
      print('❌ Error deleting contact: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // ==============================
  // ✅ ADMIN METHODS
  // ==============================

  Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.adminUsersUrl),
        headers: await getHeaders(),
      );

      print('👥 Get All Users Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as List;
      } else {
        throw Exception('Failed to load users: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAdminEmergencyAlerts() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.adminAlertsUrl),
        headers: await getHeaders(),
      );

      print('🚨 Get Admin Alerts Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as List;
      } else {
        throw Exception('Failed to load alerts: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting alerts: $e');
      return [];
    }
  }
}