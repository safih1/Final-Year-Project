import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart'; // ADD THIS IMPORT
import '../models/high_risk_zone.dart';

class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  List<HighRiskZone> _highRiskZones = [];
  StreamSubscription<Position>? _positionStream;
  HighRiskZone? _currentZone;
  bool _isMonitoring = false;

  // Callbacks
  Function(HighRiskZone zone, double distance)? onEnterZone;
  Function(HighRiskZone zone)? onExitZone;
  Function(HighRiskZone zone, double distance)? onNearZone;
  Function(Position position)? onLocationUpdate;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
    _loadHighRiskZones();
  }

  void _loadHighRiskZones() {
    _highRiskZones = [
      HighRiskZone(
        id: '1',
        name: 'Downtown Crime Hotspot',
        description: 'High theft and assault incidents reported',
        center: LatLng(33.6844, 73.0479),
        radiusMeters: 500,
        riskLevel: RiskLevel.high,
        lastIncident: DateTime.now().subtract(const Duration(days: 2)),
      ),
      HighRiskZone(
        id: '2',
        name: 'Dark Alley Area',
        description: 'Poor lighting, reported harassment cases',
        center: LatLng(33.7077, 73.0533),
        radiusMeters: 300,
        riskLevel: RiskLevel.medium,
        lastIncident: DateTime.now().subtract(const Duration(days: 7)),
      ),
      HighRiskZone(
        id: '3',
        name: 'Restricted Zone',
        description: 'Extreme danger - Gang activity reported',
        center: LatLng(33.6973, 73.0515),
        radiusMeters: 800,
        riskLevel: RiskLevel.extreme,
        lastIncident: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];
    print('📍 Loaded ${_highRiskZones.length} high-risk zones');
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isMonitoring = true;
    print('🛰️ Geofencing monitoring started');

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onLocationUpdate);
  }

  void _onLocationUpdate(Position position) {
    onLocationUpdate?.call(position);

    for (var zone in _highRiskZones) {
      double distance = calculateDistance(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= zone.radiusMeters) {
        if (_currentZone?.id != zone.id) {
          _currentZone = zone;
          _handleZoneEntry(zone, distance);
        }
      } else if (distance <= zone.radiusMeters + 100) {
        _handleNearZone(zone, distance);
      } else if (_currentZone?.id == zone.id) {
        _handleZoneExit(zone);
        _currentZone = null;
      }
    }
  }

  void _handleZoneEntry(HighRiskZone zone, double distance) {
    print('⚠️ ENTERED HIGH-RISK ZONE: ${zone.name}');
    onEnterZone?.call(zone, distance);
    _showNotification(
      title: '⚠️ ENTERING HIGH-RISK ZONE',
      body: '${zone.name}\n${zone.description}',
      priority: Priority.max,
      importance: Importance.max,
      playSound: true,
    );
  }

  void _handleNearZone(HighRiskZone zone, double distance) {
    double distanceToEdge = distance - zone.radiusMeters;
    if (distanceToEdge < 50) {
      onNearZone?.call(zone, distanceToEdge);
      _showNotification(
        title: '⚠️ APPROACHING HIGH-RISK ZONE',
        body: 'You are ${distanceToEdge.round()}m from ${zone.name}. Stay alert!',
        priority: Priority.high,
        importance: Importance.high,
      );
    }
  }

  void _handleZoneExit(HighRiskZone zone) {
    print('✅ EXITED HIGH-RISK ZONE: ${zone.name}');
    onExitZone?.call(zone);
    _showNotification(
      title: '✅ Exited High-Risk Zone',
      body: 'You have left ${zone.name}. Stay safe!',
      priority: Priority.low,
      importance: Importance.low,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required Priority priority,
    required Importance importance,
    bool playSound = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Notifications for high-risk zone alerts',
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  // CHANGED FROM _calculateDistance TO calculateDistance (public)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  void stopMonitoring() {
    _positionStream?.cancel();
    _isMonitoring = false;
    _currentZone = null;
    print('🛑 Geofencing monitoring stopped');
  }

  List<HighRiskZone> getAllZones() => _highRiskZones;
  HighRiskZone? getCurrentZone() => _currentZone;
  bool isMonitoring() => _isMonitoring;

  void addZone(HighRiskZone zone) {
    _highRiskZones.add(zone);
    print('➕ Added zone: ${zone.name}');
  }

  void removeZone(String zoneId) {
    _highRiskZones.removeWhere((z) => z.id == zoneId);
    print('➖ Removed zone: $zoneId');
  }

  void dispose() {
    stopMonitoring();
  }
}