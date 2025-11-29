import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.13:8000/api';

  // ==============================
  // TOKEN MANAGEMENT
  // ==============================

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<Map<String, dynamic>>> getUserEmergencyHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emergency/alerts/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/users/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('Error getting all users: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<List<dynamic>> getAdminEmergencyAlerts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emergency/admin/alerts/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required');
      } else {
        throw Exception('Failed to load emergency alerts');
      }
    } catch (e) {
      print('Error getting emergency alerts: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<List<dynamic>> getAdminEmergencyContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emergency/admin/contacts/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required');
      } else {
        throw Exception('Failed to load emergency contacts');
      }
    } catch (e) {
      print('Error getting admin contacts: $e');
      throw Exception('Network error: $e');
    }
  }

  // ==============================
  // EMERGENCY SETTINGS
  // ==============================

  Future<Map<String, dynamic>> getEmergencySettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emergency/settings/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {
        'video_monitoring': true,
        'motion_detection': true,
        'camera_monitoring': false,
        'auto_call_authorities': false,
        'emergency_message': 'I need help! This is an emergency.'
      };
    } catch (e) {
      print('Error getting emergency settings: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> updateEmergencySettings(
      Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/emergency/settings/'),
        headers: await getHeaders(),
        body: json.encode(settings),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
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


  // ==============================
  // AUTH
  // ==============================
  // Add this debug method to your ApiService class
  Future<void> debugToken() async {
    final token = await getToken();
    print('Current token: $token');

    if (token != null) {
      // Test the token by making a simple authenticated request
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/auth/profile/'),
          headers: await getHeaders(),
        );
        print('Token test - Status: ${response.statusCode}');
        print('Token test - Response: ${response.body}');
      } catch (e) {
        print('Token test failed: $e');
      }
    } else {
      print('No token found');
    }
  }
  // User Registration
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
      print('URL: $baseUrl/auth/register/');
      print('Body: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
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

  // User Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
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
  // EMERGENCY CONTACTS
  // ==============================

  // Replace the existing getEmergencyContacts method in ApiService
  // Replace your getEmergencyContacts method with this version
  Future<List<dynamic>> getEmergencyContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emergency/contacts/'),
        headers: await getHeaders(),
      );

      print('Emergency contacts response status: ${response.statusCode}');
      print('Emergency contacts response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle DRF paginated response
        if (responseData is Map && responseData.containsKey('results')) {
          // This is a paginated response from Django REST Framework
          return responseData['results'] ?? [];
        }
        // Handle direct array response (if pagination is disabled)
        else if (responseData is List) {
          return responseData;
        }
        // Handle error response
        else if (responseData is Map && responseData.containsKey('error')) {
          throw Exception(responseData['error']);
        }
        else {
          throw Exception('Unexpected response format');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Permission denied');
      } else {
        // Try to parse error message from response
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'HTTP ${response.statusCode}');
        } catch (e) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      print('Error getting contacts: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network connection error. Check your internet connection.');
      }
      throw Exception(e.toString());
    }
  }

  // Replace the existing addEmergencyContact method in ApiService
  Future<Map<String, dynamic>> addEmergencyContact(
      Map<String, String> contact) async {
    try {
      final requestData = {
        'name': contact['name'],
        'phone_number': contact['phone'], // Note: backend expects 'phone_number', not 'phone'
        'relationship': contact['relationship'] ?? 'Contact',
        'is_primary': false,
      };

      print('Adding emergency contact: $requestData');

      final response = await http.post(
        Uri.parse('$baseUrl/emergency/contacts/'),
        headers: await getHeaders(),
        body: json.encode(requestData),
      );

      print('Add contact response status: ${response.statusCode}');
      print('Add contact response body: ${response.body}');

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
      print('Error adding emergency contact: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateEmergencyContact(
      int contactId, Map<String, String> contact) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/emergency/contacts/$contactId/'),
        headers: await getHeaders(),
        body: json.encode({
          'name': contact['name'],
          'phone_number': contact['phone'],
          'relationship': contact['relationship'] ?? 'Contact',
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/emergency/contacts/$contactId/'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        return json.decode(response.body);
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // ==============================
  // TRIGGER EMERGENCY
  // ==============================

  Future<Map<String, dynamic>> triggerEmergency({
    required String alertType,
    double? latitude,
    double? longitude,
    String? address,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emergency/trigger/'),
        headers: await getHeaders(),
        body: json.encode({
          'alert_type': alertType,
          'location_latitude': latitude?.toString(),
          'location_longitude': longitude?.toString(),
          'location_address': address,
          'description': description,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }
}
