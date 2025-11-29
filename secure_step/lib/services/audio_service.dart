import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // API URL
  final String API_URL = 'http://192.168.1.13:8000/api/emergency/predict-audio/';

  Function(bool isThreat, double confidence)? onPredictionResult;

  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDir.path}/temp_audio.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
        _isRecording = true;
        print("🎙️ Audio recording started");

        // Record for 5 seconds
        Timer(const Duration(seconds: 5), () async {
          await stopRecordingAndPredict(filePath);
        });
      }
    } catch (e) {
      print("❌ Error starting audio recording: $e");
    }
  }

  Future<void> stopRecordingAndPredict(String filePath) async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      print("🎙️ Audio recording stopped: $path");

      if (path != null) {
        // For now, we are simulating feature extraction or sending the file
        // In a real scenario, you'd upload the file or extract features here
        // Sending dummy data to trigger the backend placeholder
        
        print('📤 Sending audio file to: $API_URL');
        
        var request = http.MultipartRequest('POST', Uri.parse(API_URL));
        request.files.add(await http.MultipartFile.fromPath('file', path));
        
        var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
        var response = await http.Response.fromStream(streamedResponse);

        print('📥 Audio Response: ${response.statusCode} ${response.body}');

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (onPredictionResult != null) {
            onPredictionResult!(
              result['is_threat'] ?? false,
              (result['confidence'] ?? 0.0).toDouble(),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Audio Prediction Error: $e');
      _isRecording = false;
    }
  }
}
