import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import '../config/api_config.dart';  // ✅ IMPORT CONFIG

class CombinedDetectionService {
  static final CombinedDetectionService _instance = CombinedDetectionService._internal();
  factory CombinedDetectionService() => _instance;
  CombinedDetectionService._internal();

  // ✅ USE CENTRALIZED CONFIG INSTEAD OF HARDCODED URL
  String get API_URL => ApiConfig.predictCombinedUrl;

  // Recording state
  bool _isRecording = false;
  final List<List<double>> _sensorData = [];
  StreamSubscription? _gyroSub, _accelSub;

  // Sensor values
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0;

  // User stats
  double _age = 25, _height = 170, _weight = 70;

  // Audio recorder
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Callbacks
  Function(bool isThreat, double confidence, Map<String, dynamic> fullResult)? onPredictionResult;
  Function(String status)? onStatusUpdate;

  void updateUserStats(double age, double height, double weight) {
    _age = age;
    _height = height;
    _weight = weight;
  }

  Future<void> startDetection() async {
    if (_isRecording) return;

    _isRecording = true;
    _sensorData.clear();

    onStatusUpdate?.call('🎤 Recording audio and movement...');
    print('🚨 THREAT DETECTION STARTED - Recording for 10 seconds');

    // Start audio recording
    String? audioPath = await _startAudioRecording();

    // Start sensor recording
    _startSensorRecording();

    // Record for 10 seconds
    await Future.delayed(const Duration(seconds: 10));

    // Stop recording
    await _stopRecording(audioPath);
  }

  Future<String?> _startAudioRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDir.path}/threat_detection_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        print('🎙️ Audio recording started: $filePath');
        return filePath;
      }
    } catch (e) {
      print('❌ Audio recording error: $e');
    }
    return null;
  }

  void _startSensorRecording() {
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

    // Record frames every 100ms
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      _recordFrame();
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

  Future<void> _stopRecording(String? audioPath) async {
    _isRecording = false;
    _gyroSub?.cancel();
    _accelSub?.cancel();

    // Stop audio recording
    String? finalAudioPath = audioPath;
    try {
      final path = await _audioRecorder.stop();
      if (path != null) finalAudioPath = path;
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }

    print('ℹ️ Recording stopped. Analyzing...');
    onStatusUpdate?.call('🔍 Analyzing threat level...');

    // Send to backend for prediction
    await _sendForPrediction(finalAudioPath);
  }

  Future<void> _sendForPrediction(String? audioPath) async {
    try {
      if (_sensorData.length < 50) {
        print('❌ Not enough sensor data (${_sensorData.length} frames)');
        onStatusUpdate?.call('❌ Insufficient data');
        return;
      }

      // Prepare movement data (last 50 frames)
      List<List<double>> sequence = _sensorData.length > 50
          ? _sensorData.sublist(_sensorData.length - 50)
          : _sensorData;

      print('📤 Sending to API: $API_URL');
      print('   Movement frames: ${sequence.length}');
      print('   Audio file: ${audioPath ?? "none"}');

      var request = http.MultipartRequest('POST', Uri.parse(API_URL));

      // Add movement data as JSON
      request.fields['movement_data'] = jsonEncode(sequence);

      // Add audio file if exists
      if (audioPath != null && File(audioPath).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('audio_file', audioPath));
        print('   Audio file size: ${File(audioPath).lengthSync()} bytes');
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Response: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        bool isThreat = result['is_threat'] ?? false;
        double confidence = (result['combined_confidence'] ?? 0.0).toDouble();

        print('');
        print('╔═══════════════════════════════════════╗');
        print('🎯 THREAT DETECTION RESULT');
        print('╠═══════════════════════════════════════╣');
        print('Status: ${isThreat ? "⚠️ THREAT DETECTED" : "✅ SAFE"}');
        print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
        print('Movement: ${result['movement_result']['action']} (${(result['movement_result']['confidence'] * 100).toStringAsFixed(1)}%)');
        print('Audio: ${result['audio_result']['is_threat'] ? "THREAT" : "Safe"} (${(result['audio_result']['confidence'] * 100).toStringAsFixed(1)}%)');
        print('╚═══════════════════════════════════════╝');
        print('');

        onStatusUpdate?.call(isThreat ? '⚠️ THREAT DETECTED!' : '✅ All Safe');
        onPredictionResult?.call(isThreat, confidence, result);
        if (isThreat) {
          onStatusUpdate?.call("🚨 EMERGENCY TRIGGERED");
          }
        // Clean up audio file
        if (audioPath != null && File(audioPath).existsSync()) {
          File(audioPath).deleteSync();
        }
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        onStatusUpdate?.call('❌ Analysis failed');
      }
    } catch (e) {
      print('❌ Prediction error: $e');
      onStatusUpdate?.call('❌ Error: $e');
    }
  }

  void dispose() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _audioRecorder.dispose();
  }
}