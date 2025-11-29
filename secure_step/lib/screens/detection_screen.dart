import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../services/movement_service.dart';
import '../services/background_service.dart';
import '../services/audio_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  StreamSubscription? _gyroSub, _accelSub;
  
  String _lastPrediction = 'No prediction yet';
  bool _isThreat = false;
  double _confidence = 0.0;
  
  String _audioStatus = 'Listening...';
  bool _isAudioThreat = false;
  
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _startListening();
    
    // Hook into MovementService results
    MovementService().onPredictionResult = (action, confidence, isThreat) {
      if (mounted) {
        setState(() {
          _lastPrediction = action;
          _confidence = confidence;
          _isThreat = isThreat;
        });
        if (isThreat) {
          _showThreatAlert("MOVEMENT THREAT: $action");
        }
      }
    };
    
    // Hook into AudioService results
    AudioService().onPredictionResult = (isThreat, confidence) {
      if (mounted) {
        setState(() {
          _isAudioThreat = isThreat;
          _audioStatus = isThreat ? "THREAT DETECTED" : "Safe";
        });
        if (isThreat) {
          _showThreatAlert("AUDIO THREAT DETECTED");
        }
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

  void _showThreatAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 30),
            const SizedBox(width: 10),
            const Text('⚠️ THREAT DETECTED', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('$message\n\nMovement Confidence: ${(_confidence * 100).toStringAsFixed(1)}%'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Mode')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Service Control
            Card(
              color: _isServiceRunning ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              child: ListTile(
                title: const Text('Background Guardian'),
                subtitle: const Text('Listens for "Help" to start detection'),
                trailing: Switch(
                  value: _isServiceRunning,
                  onChanged: (val) => _toggleService(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Sensor Data
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Live Sensors', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Gyro: ${_gyroX.toStringAsFixed(2)}, ${_gyroY.toStringAsFixed(2)}, ${_gyroZ.toStringAsFixed(2)}'),
                    Text('Accel: ${_accelX.toStringAsFixed(2)}, ${_accelY.toStringAsFixed(2)}, ${_accelZ.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Manual Trigger
            ElevatedButton.icon(
              onPressed: () {
                MovementService().startRecording();
                AudioService().startRecording();
              },
              icon: const Icon(Icons.motion_photos_on),
              label: const Text('Record 10s Manually (Movement + Audio)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Last Prediction
            if (_lastPrediction != 'No prediction yet')
              Card(
                color: _isThreat ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isThreat ? 'THREAT' : 'SAFE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _isThreat ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_lastPrediction.toUpperCase(), style: const TextStyle(fontSize: 20)),
                      Text('Confidence: ${(_confidence * 100).toStringAsFixed(1)}%'),
                      const SizedBox(height: 10),
                      Divider(),
                      const Text("Audio Status", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_audioStatus, style: TextStyle(
                        color: _isAudioThreat ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
