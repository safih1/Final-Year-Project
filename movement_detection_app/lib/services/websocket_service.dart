import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Function(Map<String, dynamic>)? onPoliceLocationUpdate;
  Function(Map<String, dynamic>)? onEmergencyResolved;

  void connect(int userId) {
    try {
      print('🔌 Connecting to WebSocket: ${ApiConfig.websocketUrl}$userId/');
      
      _channel = WebSocketChannel.connect(
        Uri.parse('${ApiConfig.websocketUrl}$userId/'),
      );

      _channel!.stream.listen(
        (message) {
          print('📨 WebSocket message received: $message');
          
          try {
            final data = jsonDecode(message);
            final String type = data['type'] ?? '';

            switch (type) {
              case 'police_location_update':
                onPoliceLocationUpdate?.call(data);
                break;
              case 'emergency_resolved':
                onEmergencyResolved?.call(data);
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