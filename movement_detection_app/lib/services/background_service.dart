import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'combined_detection_service.dart';
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description: 'This channel is used for important notifications.', // description
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
        autoStart: false, // User should enable it manually
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

  // Use combined detection service
  final detectionService = CombinedDetectionService();

  detectionService.onPredictionResult = (isThreat, confidence, fullResult) {
    if (isThreat) {
      service.invoke(
        'threat_detected',
        {
          'is_threat': true,
          'confidence': confidence,
          'movement_action': fullResult['movement_result']['action'],
          'audio_threat': fullResult['audio_result']['is_threat'],
        },
      );

      // Show critical notification
      FlutterLocalNotificationsPlugin().show(
        889,
        '⚠️ THREAT DETECTED',
        'Confidence: ${(confidence * 100).toStringAsFixed(1)}% - Emergency services alerted',
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

          // Start combined detection
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