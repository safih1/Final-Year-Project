import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  Future<void> updateLocation(double lat, double lng) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/police/officers/location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lng}),
      );
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
      throw Exception('Failed to load tasks');
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
      throw Exception('Failed to update task status');
    }
  }
}
