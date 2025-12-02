import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'combined_detection_service.dart';
import 'api_service.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'Guardian Service',
      description: 'Listening for emergency triggers',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // ✅ FIXED: Proper syntax for accessing platform-specific implementation
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'SecureStep Guardian',
        initialNotificationContent: 'Listening for "Help" trigger...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    // Request permissions first
    final micPermission = await Permission.microphone.request();
    final locationPermission = await Permission.location.request();
    
    if (!micPermission.isGranted) {
      throw Exception('Microphone permission denied');
    }
    
    if (!locationPermission.isGranted) {
      throw Exception('Location permission denied');
    }

    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      service.startService();
    }
  }
  
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final SpeechToText speech = SpeechToText();
  bool isListening = false;
  final detectionService = CombinedDetectionService();
  final apiService = ApiService();

  print('🎤 Background service started - Initializing speech recognition...');

  //////////////////////////// Initialize notifications
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  // Automatic threat detection callback
  detectionService.onPredictionResult = (isThreat, confidence, fullResult) async {
    if (isThreat) {
      print('⚠️ THREAT DETECTED - TRIGGERING AUTOMATIC EMERGENCY');
      
      // Show critical notification
      await notifications.show(
        889,
        '🚨 THREAT DETECTED',
        'Confidence: ${(confidence * 100).toStringAsFixed(1)}% - Alerting emergency services!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Guardian Service',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            
          ),
        ),
      );
            service.invoke('threat_detected', {
        'is_threat': isThreat,
        'confidence': confidence,
        'detected_action': fullResult['detected_action'] ?? 'Unknown',
        'audio_confidence': fullResult['audio_confidence'] ?? 0.0,
        'movement_confidence': fullResult['movement_confidence'] ?? 0.0,
        'timestamp': DateTime.now().toIso8601String(),
      });

    } else {
      print('✅ No threat detected - All clear');
      
      await notifications.show(
        890,
        '✅ All Clear',
        'No threat detected. Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Guardian Service',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
      // Get location and trigger emergency
      try {
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          print('⚠️ Could not get location: $e');
        }

        final double lat = position?.latitude ?? 34.1688;
        final double lng = position?.longitude ?? 73.2215;
        final String locationStr = "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}";

        final result = await apiService.triggerEmergency(
          alertType: 'automatic',
          address: locationStr,
          latitude: lat,
          longitude: lng,
          description: 'Automatic threat detection: ${fullResult['detected_action'] ?? 'Unknown'} '
                      '(Confidence: ${(confidence * 100).toStringAsFixed(1)}%)',
        );

        if (result['alert'] != null) {
          print('✅ Emergency alert sent successfully');
          
          await notifications.show(
            890,
            '✅ Emergency Alert Sent',
            'Police and emergency contacts notified!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'Guardian Service',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      } catch (e) {
        print('❌ Error triggering emergency: $e');
      }
    }
  };

  // Initialize Speech Recognition
  bool available = await speech.initialize(
    onStatus: (status) {
      print('🎤 Speech status: $status');
      if (status == 'done' || status == 'notListening') {
        isListening = false;
        // Restart listening after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          _startListeningLoop(speech, service, detectionService, notifications);
        });
      }
    },
    onError: (error) {
      print('❌ Speech error: $error');
      isListening = false;
      // Restart listening after error
      Future.delayed(const Duration(seconds: 2), () {
        _startListeningLoop(speech, service, detectionService, notifications);
      });
    },
  );

  if (available) {
    print('✅ Speech recognition initialized successfully');
    _startListeningLoop(speech, service, detectionService, notifications);
  } else {
    print('❌ Speech recognition not available');
    await notifications.show(
      888,
      '❌ Voice Recognition Failed',
      'Please check microphone permissions',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'Guardian Service',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  service.on('stopService').listen((event) {
    print('🛑 Stopping background service...');
    speech.stop();
    detectionService.dispose();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

void _startListeningLoop(
  SpeechToText speech, 
  ServiceInstance service, 
  CombinedDetectionService detectionService,
  FlutterLocalNotificationsPlugin notifications,
) async {
  if (speech.isListening) {
    print('⚠️ Already listening, skipping...');
    return;
  }

  try {
    print('🎤 Starting to listen for "Help"...');
    
    await speech.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        print('🎤 Heard: "$words" (confidence: ${result.confidence})');

        // Check for wake words
        if (words.contains('help') || 
            words.contains('emergency') || 
            words.contains('danger')) {
          print('🚨 WAKE WORD DETECTED: "$words"');

          // Show notification
          notifications.show(
            888,
            '🚨 THREAT DETECTION ACTIVATED',
            'Recording audio and movement for 10 seconds...',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'Guardian Service',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
            ),
          );

          // Start combined detection
          detectionService.startDetection();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  } catch (e) {
    print('❌ Listen error: $e');
    await Future.delayed(const Duration(seconds: 3));
    _startListeningLoop(speech, service, detectionService, notifications);
  }
}