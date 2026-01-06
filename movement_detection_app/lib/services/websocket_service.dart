import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Function(Map<String, dynamic>)? onPoliceLocationUpdate;
  Function(Map<String, dynamic>)? onEmergencyResolved;
  Function(Map<String, dynamic>)? onOfficerAssigned;
  Function(Map<String, dynamic>)? onPredictionReceived;

  void connect(int id) {
    try {
      // Construct full WebSocket URL
      final String wsUrl = '${ApiConfig.websocketUrl}$id/';
      print('🔌 Connecting to WebSocket: $wsUrl');
      
      // Parse URI properly - ensure no fragments
      final uri = Uri.parse(wsUrl);
      
      // Verify it's a WebSocket URI
      if (!uri.scheme.startsWith('ws')) {
        throw Exception('Invalid WebSocket scheme: ${uri.scheme}. Expected ws:// or wss://');
      }
      
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          print('📨 WebSocket message received: $message');
          
          try {
            final data = jsonDecode(message);
            final String type = data['type'] ?? '';

            switch (type) {
              case 'police_location_update':
              case 'officer_location': // Handle backend message type
                onPoliceLocationUpdate?.call(data);
                break;
              case 'officer_assigned':
                onOfficerAssigned?.call(data);
                break;
              case 'emergency_resolved':
                onEmergencyResolved?.call(data);
                break;
              case 'prediction_result':
                onPredictionReceived?.call(data);
                break;
              default:
                print('⚠️ Unknown WebSocket message type: $type');
            }
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
        },
      );

      print('✅ WebSocket connected successfully');
    } catch (e) {
      print('❌ Failed to connect to WebSocket: $e');
    }
  }

  // Send emergency trigger to backend
  void sendEmergencyTrigger({
    required int alertId,
    required int userId,
    required String userName,
    required String location,
    required Map<String, dynamic> coordinates,
  }) {
    if (_channel == null) {
      print('⚠️ WebSocket not connected. Cannot send emergency trigger.');
      return;
    }
    try {
      final message = jsonEncode({
        'type': 'emergency_trigger',
        'alert_id': alertId,
        'user_id': userId,
        'user_name': userName,
        'location': location,
        'coordinates': coordinates,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(message);
      print('📤 Sent emergency trigger via WebSocket');
    } catch (e) {
      print('❌ Error sending emergency trigger: $e');
    }
  }

  // Send no-threat message
  void sendNoThreat({required int userId}) {
    if (_channel == null) {
      print('⚠️ WebSocket not connected. Cannot send no-threat message.');
      return;
    }
    try {
      final message = jsonEncode({
        'type': 'no_threat',
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(message);
      print('📤 Sent no-threat message via WebSocket');
    } catch (e) {
      print('❌ Error sending no-threat message: $e');
    }
  }

  // Request a prediction after emergency is triggered
  void requestPrediction() {
    if (_channel == null) {
      print('⚠️ WebSocket not connected. Cannot request prediction.');
      return;
    }
    try {
      final message = jsonEncode({
        'type': 'request_prediction',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(message);
      print('📤 Requested prediction via WebSocket');
    } catch (e) {
      print('❌ Error requesting prediction: $e');
    }
  }

  void disconnect() {
    try {
      _channel?.sink.close();
      _channel = null;
      print('🔌 WebSocket disconnected');
    } catch (e) {
      print('❌ Error disconnecting WebSocket: $e');
    }
  }
}