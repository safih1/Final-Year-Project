import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/high_risk_zone.dart';
import '../services/geofencing_service.dart';

class HighRiskZonesScreen extends StatefulWidget {
  const HighRiskZonesScreen({super.key});

  @override
  State<HighRiskZonesScreen> createState() => _HighRiskZonesScreenState();
}

class _HighRiskZonesScreenState extends State<HighRiskZonesScreen> {
  final GeofencingService _geoService = GeofencingService();
  final MapController _mapController = MapController();

  LatLng _currentLocation = LatLng(33.6844, 73.0479); // Default: Islamabad
  bool _isMonitoring = false;
  HighRiskZone? _currentZone;
  String _statusMessage = 'Not monitoring';

  @override
  void initState() {
    super.initState();
    _initializeGeofencing();
    _getCurrentLocation();
  }

  Future<void> _initializeGeofencing() async {
    await _geoService.initialize();

    _geoService.onEnterZone = (zone, distance) {
      setState(() {
        _currentZone = zone;
        _statusMessage = '⚠️ Inside ${zone.name}';
      });
      _showZoneAlert(zone, isEntering: true);
    };

    _geoService.onExitZone = (zone) {
      setState(() {
        _currentZone = null;
        _statusMessage = '✅ Safe - Outside risk zones';
      });
    };

    _geoService.onNearZone = (zone, distance) {
      setState(() {
        _statusMessage = '⚠️ ${distance.round()}m from ${zone.name}';
      });
    };

    _geoService.onLocationUpdate = (position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    };
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, 13);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _toggleMonitoring() async {
    if (_isMonitoring) {
      _geoService.stopMonitoring();
      setState(() {
        _isMonitoring = false;
        _statusMessage = 'Monitoring stopped';
      });
    } else {
      try {
        await _geoService.startMonitoring();
        setState(() {
          _isMonitoring = true;
          _statusMessage = 'Monitoring active';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showZoneAlert(HighRiskZone zone, {required bool isEntering}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _getRiskColor(zone.riskLevel).withOpacity(0.1),
        title: Row(
          children: [
            Icon(Icons.warning, color: _getRiskColor(zone.riskLevel), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEntering ? '⚠️ HIGH-RISK ZONE' : 'Approaching Risk Zone',
                style: TextStyle(color: _getRiskColor(zone.riskLevel)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zone.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(zone.description),
            const SizedBox(height: 10),
            Text('Risk Level: ${zone.riskLevel.toString().split('.').last.toUpperCase()}',
                style: TextStyle(
                    color: _getRiskColor(zone.riskLevel),
                    fontWeight: FontWeight.bold)),
            if (zone.lastIncident != null) ...[
              const SizedBox(height: 10),
              Text('Last Incident: ${_formatDate(zone.lastIncident!)}',
                  style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Trigger emergency or navigate away
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _getRiskColor(zone.riskLevel)),
            child: const Text('GET HELP'),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.yellow.shade700;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
      case RiskLevel.extreme:
        return Colors.red.shade900;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = _geoService.getAllZones();

    return Scaffold(
      appBar: AppBar(
        title: const Text('High-Risk Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isMonitoring
                ? (_currentZone != null
                ? _getRiskColor(_currentZone!.riskLevel).withOpacity(0.2)
                : Colors.green.withOpacity(0.2))
                : Colors.grey.withOpacity(0.2),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Switch(
                      value: _isMonitoring,
                      onChanged: (val) => _toggleMonitoring(),
                    ),
                  ],
                ),
                if (_currentZone != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Currently in: ${_currentZone!.name}',
                    style: TextStyle(
                        color: _getRiskColor(_currentZone!.riskLevel),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.secure_step',
                ),

                // Risk zone circles
                CircleLayer(
                  circles: zones.map((zone) {
                    return CircleMarker(
                      point: zone.center,
                      radius: zone.radiusMeters,
                      useRadiusInMeter: true,
                      color: _getRiskColor(zone.riskLevel).withOpacity(0.3),
                      borderColor: _getRiskColor(zone.riskLevel),
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),

                // Zone markers
                MarkerLayer(
                  markers: zones.map((zone) {
                    return Marker(
                      point: zone.center,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showZoneInfo(zone),
                        child: Icon(
                          Icons.warning,
                          color: _getRiskColor(zone.riskLevel),
                          size: 40,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Current location marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Zone List
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: zones.length,
              itemBuilder: (context, index) {
                final zone = zones[index];
                final distance = _geoService.calculateDistance(
                  _currentLocation.latitude,
                  _currentLocation.longitude,
                  zone.center.latitude,
                  zone.center.longitude,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).primaryColor,
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: _getRiskColor(zone.riskLevel),
                      size: 32,
                    ),
                    title: Text(zone.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zone.description),
                        Text(
                          '${(distance / 1000).toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        zone.riskLevel.toString().split('.').last.toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: _getRiskColor(zone.riskLevel).withOpacity(0.2),
                    ),
                    onTap: () {
                      _mapController.move(zone.center, 15);
                      _showZoneInfo(zone);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showZoneInfo(HighRiskZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: _getRiskColor(zone.riskLevel), size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(zone.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(zone.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text('Risk Level: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(
                    zone.riskLevel.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _getRiskColor(zone.riskLevel),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Coverage: ${zone.radiusMeters.round()}m radius'),
            if (zone.lastIncident != null)
              Text('Last Incident: ${_formatDate(zone.lastIncident!)}',
                  style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _mapController.move(zone.center, 15);
              },
              icon: const Icon(Icons.map),
              label: const Text('Show on Map'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _geoService.dispose();
    super.dispose();
  }
}