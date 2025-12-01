import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';
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
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

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
        initialNotificationTitle: 'Secure Step Guardian',
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

  // ✅ AUTOMATIC EMERGENCY TRIGGER ON THREAT DETECTION
  detectionService.onPredictionResult = (isThreat, confidence, fullResult) async {
    if (isThreat) {
      print('⚠️ THREAT DETECTED - TRIGGERING AUTOMATIC EMERGENCY');
      
      // Show critical notification
      FlutterLocalNotificationsPlugin().show(
        889,
        '🚨 THREAT DETECTED',
        'Confidence: ${(confidence * 100).toStringAsFixed(1)}% - Alerting emergency services!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );

      // ✅ AUTOMATICALLY TRIGGER EMERGENCY WITH LOCATION
      try {
        // Get current location
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          print('⚠️ Location services disabled - using default location');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          print('⚠️ Could not get location: $e');
        }

        final double lat = position?.latitude ?? 34.1688;  // Default: Abbottabad
        final double lng = position?.longitude ?? 73.2215;
        final String locationStr = "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}";

        // Trigger emergency via API
        final result = await apiService.triggerEmergency(
          alertType: 'automatic',
          address: locationStr,
          latitude: lat,
          longitude: lng,
          description: 'Automatic threat detection: ${fullResult['detected_action'] ?? 'Unknown'} '
                      '(Confidence: ${(confidence * 100).toStringAsFixed(1)}%)',
        );

        if (result['alert'] != null) {
          print('✅ Emergency alert sent successfully: Alert ID ${result['alert']['id']}');
          
          // Send notification of success
          FlutterLocalNotificationsPlugin().show(
            890,
            '✅ Emergency Alert Sent',
            'Police and emergency contacts have been notified. Help is on the way!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'MY FOREGROUND SERVICE',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        } else {
          print('❌ Failed to send emergency alert: ${result['error']}');
        }
      } catch (e) {
        print('❌ Error triggering automatic emergency: $e');
      }
    }
  };

  // Initialize Speech
  bool available = await speech.initialize(
    onStatus: (status) {
      print('Speech status: $status');
      if (status == 'done' || status == 'notListening') {
        isListening = false;
        _startListeningLoop(speech, service, detectionService);
      }
    },
    onError: (error) {
      print('Speech error: $error');
      isListening = false;
      _startListeningLoop(speech, service, detectionService);
    },
  );

  if (available) {
    _startListeningLoop(speech, service, detectionService);
  }

  service.on('stopService').listen((event) {
    detectionService.dispose();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

void _startListeningLoop(SpeechToText speech, ServiceInstance service, CombinedDetectionService detectionService) async {
  if (speech.isListening) return;

  try {
    await speech.listen(
      onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        print('🎤 Heard: "$words"');

        if (words.contains('help')) {
          print('🚨 WAKE WORD "HELP" DETECTED!');

          // Show notification
          FlutterLocalNotificationsPlugin().show(
            888,
            '🚨 THREAT DETECTION ACTIVATED',
            'Recording audio and movement for 10 seconds...',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'MY FOREGROUND SERVICE',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );

          // Start combined detection (will auto-trigger emergency if threat detected)
          detectionService.startDetection();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.dictation,
    );
  } catch (e) {
    print('❌ Listen error: $e');
    await Future.delayed(const Duration(seconds: 2));
    _startListeningLoop(speech, service, detectionService);
  }
}