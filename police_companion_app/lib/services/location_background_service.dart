import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

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
        foregroundServiceNotificationId: 222,
        notificationIcon: 'ic_police', // <<< FIXED
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onBackground: onIosBackground,
        onForeground: onStart,
      ),
    );
  }
}

@pragma("vm:entry-point")
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma("vm:entry-point")
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final api = ApiService();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Police Service Active",
      content: "Background location running...",
    );
  }

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print("Location updated: ${pos.latitude}, ${pos.longitude}");

      await api.updateLocation(pos.latitude, pos.longitude);

      service.invoke('update', {
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (e) {
      print("Background error: $e");
    }
  });
}
