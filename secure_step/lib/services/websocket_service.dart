import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onPoliceLocationUpdate;
  Function(Map<String, dynamic>)? onEmergencyResolved;

  void connect(int userId) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.8:8000/ws/user/$userId/'),
      );

      _channel!.stream.listen(
            (message) {
          print('RAW MESSAGE: $message');
          final data = json.decode(message);
          print('PARSED DATA: $data');

          if (data['type'] == 'location_update' && onPoliceLocationUpdate != null) {
            print('Calling onPoliceLocationUpdate callback');
            onPoliceLocationUpdate!(data['data']);
          } else if (data['type'] == 'emergency_resolved' && onEmergencyResolved != null) {
            print('Emergency resolved by police');
            onEmergencyResolved!(data['data']);
          }
        },
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket closed'),
      );

      print('User WebSocket connected for user $userId');
    } catch (e) {
      print('WebSocket connection failed: $e');
    }
  }

  void sendEmergencyTrigger({
    required int alertId,
    required int userId,
    required String userName,
    required String location,
    required Map<String, double> coordinates,
  }) {
    if (_channel != null) {
      final message = json.encode({
        'type': 'emergency_trigger',
        'alert_id': alertId,
        'user_id': userId,
        'user_name': userName,
        'location': location,
        'coordinates': coordinates,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _channel!.sink.add(message);
      print('Emergency sent via WebSocket');
    }
  }

  void sendNoThreat({required int userId}) {
    if (_channel != null) {
      final message = json.encode({
        'type': 'no_threat',
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _channel!.sink.add(message);
      print('No threat message sent via WebSocket');
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}