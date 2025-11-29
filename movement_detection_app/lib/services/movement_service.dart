import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;

class MovementService {
  static final MovementService _instance = MovementService._internal();
  factory MovementService() => _instance;
  MovementService._internal();

  List<List<double>> _sensorData = [];
  StreamSubscription? _gyroSub, _accelSub;
  
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  
  bool _isRecording = false;
  
  // Default user stats (should be updated from profile)
  double _age = 25, _height = 170, _weight = 70;

  // API URL - Updated to point to Django backend
  final String API_URL = 'http://192.168.1.13:8000/api/emergency/predict/';

  Function(String action, double confidence, bool isThreat)? onPredictionResult;

  void updateUserStats(double age, double height, double weight) {
    _age = age;
    _height = height;
    _weight = weight;
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    
    _isRecording = true;
    _sensorData.clear();
    
    // Start listening to sensors
    _gyroSub = gyroscopeEvents.listen((e) {
      _gyroX = e.x;
      _gyroY = e.y;
      _gyroZ = e.z;
    });

    _accelSub = accelerometerEvents.listen((e) {
      _accelX = e.x;
      _accelY = e.y;
      _accelZ = e.z;
    });

    // Record for 10 seconds
    int ticks = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (ticks >= 100) { // 10 seconds (100 * 100ms)
        timer.cancel();
        stopRecordingAndPredict();
      } else {
        _recordFrame();
        ticks++;
      }
    });
  }

  void _recordFrame() {
    double pitch = atan2(_accelY, sqrt(_accelX * _accelX + _accelZ * _accelZ)) * 180 / pi;
    double roll = atan2(-_accelX, _accelZ) * 180 / pi;
    double bmi = _weight / pow(_height / 100, 2);

    _sensorData.add([
      _gyroX, _gyroY, _gyroZ,
      _accelX, _accelY, _accelZ,
      pitch, roll,
      _age, _height, _weight, bmi
    ]);
  }

  Future<void> stopRecordingAndPredict() async {
    _isRecording = false;
    _gyroSub?.cancel();
    _accelSub?.cancel();

    try {
      if (_sensorData.length < 50) {
        print('Not enough data for prediction');
        return;
      }

      // Take last 50 frames if more than 50, or pad if needed (but we expect ~100)
      List<List<double>> sequence = _sensorData.length > 50 
          ? _sensorData.sublist(_sensorData.length - 50) 
          : _sensorData;

      print('📤 Sending movement data to: $API_URL');
      
      final response = await http.post(
        Uri.parse(API_URL),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': sequence}),
      ).timeout(const Duration(seconds: 10));

      print('📥 Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (onPredictionResult != null) {
          onPredictionResult!(
            result['action'],
            result['confidence'],
            result['is_threat']
          );
        }
      }
    } catch (e) {
      print('❌ Prediction Error: $e');
    }
  }
}
