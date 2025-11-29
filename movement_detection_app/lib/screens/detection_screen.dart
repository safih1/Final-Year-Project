import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../services/combined_detection_service.dart';
import '../services/background_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  StreamSubscription? _gyroSub, _accelSub;

  bool _isThreat = false;
  double _confidence = 0.0;
  Map<String, dynamic>? _lastResult;
  String _status = 'Ready';

  bool _isServiceRunning = false;
  bool _isManualRecording = false;

  final CombinedDetectionService _detectionService = CombinedDetectionService();

  @override
  void initState() {
    super.initState();
    _startListening();

    // Hook into detection service
    _detectionService.onPredictionResult = (isThreat, confidence, fullResult) {
      if (mounted) {
        setState(() {
          _isThreat = isThreat;
          _confidence = confidence;
          _lastResult = fullResult;
          _status = isThreat ? 'THREAT DETECTED' : 'Safe';
          _isManualRecording = false;
        });

        if (isThreat) {
          _showThreatAlert(fullResult);
        }
      }
    };

    _detectionService.onStatusUpdate = (status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    };
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  void _startListening() {
    _gyroSub = gyroscopeEvents.listen((e) {
      if (mounted) {
        setState(() {
          _gyroX = e.x;
          _gyroY = e.y;
          _gyroZ = e.z;
        });
      }
    });

    _accelSub = accelerometerEvents.listen((e) {
      if (mounted) {
        setState(() {
          _accelX = e.x;
          _accelY = e.y;
          _accelZ = e.z;
        });
      }
    });
  }

  void _toggleService() async {
    if (_isServiceRunning) {
      await BackgroundService().stopService();
      setState(() => _isServiceRunning = false);
    } else {
      await BackgroundService().initialize();
      await BackgroundService().startService();
      setState(() => _isServiceRunning = true);
    }
  }

  void _manualDetection() async {
    setState(() {
      _isManualRecording = true;
      _status = 'Recording...';
    });

    await _detectionService.startDetection();
  }

  void _showThreatAlert(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('⚠️ THREAT DETECTED', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text('Movement: ${result['movement_result']['action']}'),
            Text('Movement Confidence: ${(result['movement_result']['confidence'] * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 10),
            Text('Audio: ${result['audio_result']['is_threat'] ? "THREAT" : "Safe"}'),
            Text('Audio Confidence: ${(result['audio_result']['confidence'] * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 15),
            const Text('Emergency contacts will be notified automatically in 5 seconds...',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Cancel auto-alert
            },
            child: const Text('FALSE ALARM'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerEmergency();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CALL NOW'),
          ),
        ],
      ),
    );

    // Auto-trigger after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context);
        _triggerEmergency();
      }
    });
  }

  void _triggerEmergency() async {
    // TODO: Integrate with your emergency trigger logic from home_screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Emergency Alert Triggered!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Mode')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Background Service Toggle
              Card(
                color: _isServiceRunning ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                child: ListTile(
                  title: const Text('Background Guardian',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_isServiceRunning
                      ? '👂 Listening for "Help" keyword...'
                      : 'Tap to enable voice activation'),
                  trailing: Switch(
                    value: _isServiceRunning,
                    onChanged: (val) => _toggleService(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Live Sensor Data
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Live Sensors',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text('Gyro: ${_gyroX.toStringAsFixed(2)}, ${_gyroY.toStringAsFixed(2)}, ${_gyroZ.toStringAsFixed(2)}'),
                      Text('Accel: ${_accelX.toStringAsFixed(2)}, ${_accelY.toStringAsFixed(2)}, ${_accelZ.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Status
              Text(_status,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isManualRecording ? Colors.orange : Colors.white)),

              const SizedBox(height: 20),

              // Manual Trigger
              ElevatedButton.icon(
                onPressed: _isManualRecording ? null : _manualDetection,
                icon: Icon(_isManualRecording ? Icons.refresh : Icons.motion_photos_on),
                label: Text(_isManualRecording
                    ? 'Recording... (10s)'
                    : 'Manual Detection (10s)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: _isManualRecording ? Colors.grey : null,
                ),
              ),

              const SizedBox(height: 20),

              // Last Result
              if (_lastResult != null)
                Card(
                  color: _isThreat ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isThreat ? '⚠️ THREAT DETECTED' : '✅ ALL SAFE',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _isThreat ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text('Overall Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(height: 20),
                        const Text('Movement Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Action: ${_lastResult!['movement_result']['action']}'),
                        Text('Confidence: ${(_lastResult!['movement_result']['confidence'] * 100).toStringAsFixed(1)}%'),
                        Text('Threat: ${_lastResult!['movement_result']['is_threat'] ? "YES" : "NO"}'),
                        const SizedBox(height: 10),
                        const Text('Audio Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Status: ${_lastResult!['audio_result']['is_threat'] ? "THREAT" : "Safe"}'),
                        Text('Confidence: ${(_lastResult!['audio_result']['confidence'] * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}