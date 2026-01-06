import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
      description: 'Monitoring for shake trigger',
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
        initialNotificationTitle: 'SecureStep Guardian',
        initialNotificationContent: 'SHAKE your phone 3 times to trigger detection',
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
    print('🎙️ [SERVICE] Requesting permissions...');
    final locationPermission = await Permission.location.request();
    
    print('📍 [SERVICE] Location permission: ${locationPermission.isGranted}');
    
    if (!locationPermission.isGranted) {
      print('❌ [SERVICE] Location permission DENIED');
      throw Exception('Location permission denied');
    }

    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    
    print('🎙️ [SERVICE] Service running status: $isRunning');
    
    if (!isRunning) {
      print('🎙️ [SERVICE] Starting background service...');
      service.startService();
    } else {
      print('🎙️ [SERVICE] Service already running');
    }
  }
  
  Future<void> stopService() async {
    print('🛑 [SERVICE] Stopping service...');
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final detectionService = CombinedDetectionService();
  final apiService = ApiService();

  print('==============================================');
  print('📳 [BACKGROUND] Service started');
  print('📳 [BACKGROUND] Monitoring shake gestures...');
  print('📳 [BACKGROUND] SHAKE your phone 3 times quickly to trigger');
  print('==============================================');

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  // Shake detection variables
  int shakeCount = 0;
  DateTime? lastShakeTime;
  const double shakeThreshold = 20.0; // Acceleration threshold
  const Duration shakeTimeout = Duration(seconds: 2);

  // Automatic threat detection callback
  detectionService.onPredictionResult = (isThreat, confidence, fullResult) async {
    print('🔮 [DETECTION] Prediction result received');
    print('🔮 [DETECTION] Is Threat: $isThreat');
    print('🔮 [DETECTION] Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    
    if (isThreat) {
      print('⚠️ [THREAT] THREAT DETECTED - Triggering emergency');
      
      await notifications.show(
        889,
        '🚨 THREAT DETECTED',
        'Confidence: ${(confidence * 100).toStringAsFixed(1)}% - Alerting emergency services!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Guardian Service',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
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
          print('📍 [LOCATION] Got position: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          print('⚠️ [LOCATION] Could not get location: $e');
        }

        final double lat = position?.latitude ?? 34.1688;
        final double lng = position?.longitude ?? 73.2215;
        final String locationStr = "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}";

        print('🚨 [EMERGENCY] Triggering emergency API call...');
        final result = await apiService.triggerEmergency(
          alertType: 'automatic',
          address: locationStr,
          latitude: lat,
          longitude: lng,
          description: 'Automatic threat detection: ${fullResult['detected_action'] ?? 'Unknown'} '
                      '(Confidence: ${(confidence * 100).toStringAsFixed(1)}%)',
        );

        if (result['alert'] != null) {
          print('✅ [EMERGENCY] Alert sent successfully - ID: ${result['alert']['id']}');
          
          await notifications.show(
            890,
            '✅ Emergency Alert Sent',
            'Police and emergency contacts notified!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'Guardian Service',
                icon: '@mipmap/ic_launcher',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );

          // Send threat_detected event to UI
          service.invoke('threat_detected', {
            'is_threat': isThreat,
            'confidence': confidence,
            'detected_action': fullResult['detected_action'] ?? 'Unknown',
            'audio_confidence': fullResult['audio_confidence'] ?? 0.0,
            'movement_confidence': fullResult['movement_confidence'] ?? 0.0,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('❌ [EMERGENCY] Error triggering emergency: $e');
      }

    } else {
      print('✅ [DETECTION] No threat detected - All clear');
      
      await notifications.show(
        890,
        '✅ All Clear',
        'No threat detected. Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Guardian Service',
            icon: '@mipmap/ic_launcher',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
    }
  };

  // Listen to accelerometer for shake detection
  print('📳 [SHAKE] Starting shake detection...');
  accelerometerEventStream().listen((AccelerometerEvent event) {
    // Calculate total acceleration
    double acceleration = event.x.abs() + event.y.abs() + event.z.abs();
    
    // Check if acceleration exceeds threshold
    if (acceleration > shakeThreshold) {
      DateTime now = DateTime.now();
      
      // Reset shake count if too much time has passed
      if (lastShakeTime != null && now.difference(lastShakeTime!) > shakeTimeout) {
        shakeCount = 0;
      }
      
      shakeCount++;
      lastShakeTime = now;
      
      print('📳 [SHAKE] Shake detected! Count: $shakeCount/3 (acceleration: ${acceleration.toStringAsFixed(2)})');
      
      // If 3 shakes detected within timeout period
      if (shakeCount >= 3) {
        print('');
        print('🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨');
        print('🚨 SHAKE TRIGGER DETECTED!');
        print('🚨 3 shakes registered');
        print('🚨 Starting 10-second detection...');
        print('🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨');
        print('');
        
        // Reset shake count
        shakeCount = 0;
        lastShakeTime = null;
        
        // Show notification
        notifications.show(
          888,
          '🚨 SHAKE DETECTED!',
          'Recording audio and movement for 10 seconds...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'Guardian Service',
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          ),
        );

        // Start combined detection
        print('🎬 [DETECTION] Starting combined detection...');
        detectionService.startDetection();
      }
    }
  });

  print('✅ [SHAKE] Shake detection active - shake phone 3 times to trigger!');

  service.on('stopService').listen((event) {
    print('🛑 [SERVICE] Stop command received');
    detectionService.dispose();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}