import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';


class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _emergencyController;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _badgeNumber;
  bool _isConnected = false;
  
  Stream<Map<String, dynamic>> get emergencyStream => 
      _emergencyController!.stream;
  
  bool get isConnected => _isConnected;
  
  Future<void> connect(String badgeNumber) async {
    _badgeNumber = badgeNumber;
    _emergencyController = StreamController<Map<String, dynamic>>.broadcast();
    
    await _connectWebSocket();
    _startPingTimer();
  }
  
  Future<void> _connectWebSocket() async {
    try {
       final wsUrl = 'ws://192.168.1.5:8000/ws/officer/$_badgeNumber/';

      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
      
      _isConnected = true;
      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: \$e');
      _scheduleReconnect();
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      print('WebSocket message: \$data');
      
      switch (data['type']) {
        case 'connection_established':
          print('Connection established:${data['message']}');
          break;
          
        case 'emergency_assigned':
          print('Emergency assigned: ${data['emergency']}');
          _emergencyController?.add(data['emergency']);
          break;
          
        default:
          print('Unknown message type: ${data['type']}');
      }
    } catch (e) {
      print('Error handling message: \$e');
    }
  }
  
  void _handleError(error) {
    print('WebSocket error: \$error');
    _isConnected = false;
    _scheduleReconnect();
  }
  
  void _handleDone() {
    print('WebSocket connection closed');
    _isConnected = false;
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('Attempting to reconnect...');
      _connectWebSocket();
    });
  }
  
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendPing();
      }
    });
  }
  
  void _sendPing() {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    } catch (e) {
      print('Error sending ping: \$e');
    }
  }
  
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _emergencyController?.close();
    _isConnected = false;
  }
}