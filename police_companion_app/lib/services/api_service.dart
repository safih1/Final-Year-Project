import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // IMPORTANT: Update this to your backend IP
  static const String baseUrl = 'http://192.168.1.8:8000/api/emergency';
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/police/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['tokens']['access']);
        await _storage.write(key: 'refresh_token', value: data['tokens']['refresh']);
        if (data['officer'] != null) {
          await _storage.write(key: 'officer_id', value: data['officer']['id'].toString());
        }
        return data;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<Map<String, dynamic>> registerOfficer({
    required String email,
    required String password,
    required String fullName,
    required String badgeNumber,
    required String rank,
    required String station,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/police/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'badge_number': badgeNumber,
          'rank': rank,
          'station': station,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['tokens']['access']);
        await _storage.write(key: 'refresh_token', value: data['tokens']['refresh']);
        if (data['officer'] != null) {
          await _storage.write(key: 'officer_id', value: data['officer']['id'].toString());
        }
        return data;
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      print('No access token found');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/police/officers/location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lng}),
      );

      if (response.statusCode != 200) {
        print('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<List<dynamic>> getTasks() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/police/dispatch/tasks/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load tasks: ${response.body}');
    }
  }

  Future<void> updateTaskStatus(int taskId, String status) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('No token found');

    final response = await http.put(
      Uri.parse('$baseUrl/police/dispatch/tasks/$taskId/status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update task status: ${response.body}');
    }
  }
}