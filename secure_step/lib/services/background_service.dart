import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'movement_service.dart';
import 'audio_service.dart';

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
  
  // Initialize Services
  final movementService = MovementService();
  final audioService = AudioService();
  
  movementService.onPredictionResult = (action, confidence, isThreat) {
    if (isThreat) {
      service.invoke(
        'threat_detected',
        {
          'action': action,
          'confidence': confidence,
        },
      );
      
      // Show notification
      FlutterLocalNotificationsPlugin().show(
        889,
        'THREAT DETECTED',
        'Action: $action (Confidence: ${(confidence * 100).toStringAsFixed(1)}%)',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            importance: Importance.high,
            priority: Priority.high,
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
        // Restart listening loop if service is running
        _startListeningLoop(speech, service, movementService, audioService);
      }
    },
    onError: (error) {
      print('Speech error: $error');
      isListening = false;
      _startListeningLoop(speech, service, movementService, audioService);
    },
  );

  if (available) {
    _startListeningLoop(speech, service, movementService, audioService);
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

void _startListeningLoop(SpeechToText speech, ServiceInstance service, MovementService movementService, AudioService audioService) async {
  if (speech.isListening) return;

  try {
    await speech.listen(
      onResult: (result) {
        if (result.recognizedWords.toLowerCase().contains('help')) {
          print('Wake word "Help" detected!');
          movementService.startRecording();
          audioService.startRecording();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.dictation,
    );
  } catch (e) {
    print('Listen error: $e');
    // Wait a bit and retry
    await Future.delayed(const Duration(seconds: 2));
    _startListeningLoop(speech, service, movementService, audioService);
  }
}
