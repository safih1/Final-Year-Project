import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationBackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'police_location_service',
        initialNotificationTitle: 'Police Service Active',
        initialNotificationContent: 'Updating location in background...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    final apiService = ApiService();

    Timer? periodicTimer;

    service.on('stopService').listen((event) {
      periodicTimer?.cancel();
      service.stopSelf();
    });

    periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        // 1. Update Location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        print('Updating location: ${position.latitude}, ${position.longitude}');
        await apiService.updateLocation(position.latitude, position.longitude);
        
        service.invoke(
          'update',
          {
            "lat": position.latitude,
            "lng": position.longitude,
          },
        );
        
        // 2. Check for new tasks (just logging for now)
        final tasks = await apiService.getTasks();
        final pendingTasks = tasks.where((t) => t['status'] == 'pending').toList();
        
        if (pendingTasks.isNotEmpty) {
          print('Found ${pendingTasks.length} pending tasks');
          // Tasks will be shown in the app UI via WebSocket and polling
        }
        
      } catch (e) {
        print('Error in background service: $e');
      }
    });
  }
}
