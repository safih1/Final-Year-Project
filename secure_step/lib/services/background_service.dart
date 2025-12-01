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
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for background monitoring.',
      importance: Importance.high,
    );

    final plugin = FlutterLocalNotificationsPlugin();

    await plugin
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
        initialNotificationContent: 'Voice detection running...',
        foregroundServiceNotificationId: 888,
        notificationIcon: 'ic_stat_notify', // MUST MATCH drawable!!
        foregroundServiceTypes: [
          AndroidForegroundType.microphone,
        ],
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
    if (!(await service.isRunning())) {
      await service.startService();
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

  final speech = SpeechToText();
  final movementService = MovementService();
  final audioService = AudioService();

  // Threat detection callback
  movementService.onPredictionResult = (action, confidence, isThreat) {
    if (!isThreat) return;

    FlutterLocalNotificationsPlugin().show(
      889,
      'Threat Detected!',
      'Action: $action  |  Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'MY FOREGROUND SERVICE',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_stat_notify',
        ),
      ),
    );
  };

  bool available = await speech.initialize(
    onStatus: (status) {
      if (status == 'done' || status == 'notListening') {
        _startListeningLoop(speech, service, movementService, audioService);
      }
    },
    onError: (error) {
      _startListeningLoop(speech, service, movementService, audioService);
    },
  );

  if (available) {
    _startListeningLoop(speech, service, movementService, audioService);
  }

  service.on("stopService").listen((event) {
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
  MovementService movementService,
  AudioService audioService,
) async {
  if (speech.isListening) return;

  try {
    await speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        if (text.contains('help')) {
          movementService.startRecording();
          audioService.startRecording();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.dictation,
    );
  } catch (e) {
    await Future.delayed(const Duration(seconds: 2));
    _startListeningLoop(speech, service, movementService, audioService);
  }
}
