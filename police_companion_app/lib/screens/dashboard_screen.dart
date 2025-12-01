import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<dynamic> _tasks = [];
  List<Marker> _markers = [];
  LatLng _initialPosition = const LatLng(34.1688, 73.2215);

  WebSocketChannel? _channel;
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _getCurrentLocation();
    _connectWebSocket();
    // Listen to background service updates
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event['lat'] != null && event['lng'] != null) {
        _updateMyMarker(event['lat'], event['lng']);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
      });
      _updateMyMarker(position.latitude, position.longitude);
      _mapController.move(_initialPosition, 15.0);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateMyMarker(double lat, double lng) {
    setState(() {
      // Remove previous location marker
      _markers.removeWhere((m) => m.point == _initialPosition);
      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 50,
          height: 50,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    });
  }

  Future<void> _connectWebSocket() async {
    try {
      final officerId = await _storage.read(key: 'officer_id');
      if (officerId == null) {
        print('No officer ID found');
        return;
      }
      final wsUrl = 'ws://192.168.1.8:8000/ws/police/$officerId/';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen((message) {
        print('WebSocket message: $message');
        _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 NEW TASK ASSIGNED! Check your dashboard'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 10),
            ),
          );
        }
      }, onError: (error) {
        print('WebSocket error: $error');
      }, cancelOnError: false);
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _apiService.getTasks();
      setState(() {
        _tasks = tasks;
        _updateTaskMarkers();
      });
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  void _updateTaskMarkers() {
    // Preserve current location marker if present
    Marker? myMarker;
    try {
      myMarker = _markers.firstWhere((m) => m.point == _initialPosition);
    } catch (_) {}
    _markers.clear();
    if (myMarker != null) _markers.add(myMarker);
    for (var task in _tasks) {
      if (task['emergency'] != null &&
          task['emergency']['location'] != null &&
          task['emergency']['location']['latitude'] != null) {
        final lat = task['emergency']['location']['latitude'];
        final lng = task['emergency']['location']['longitude'];
        _markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 50,
            height: 50,
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptTask(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'accepted');
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineTask(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'declined');
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialPosition,
                initialZoom: 14.0,
                minZoom: 5.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.police_companion_app',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: _tasks.isEmpty
                ? const Center(child: Text('No active tasks'))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text('Task #${task['id']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Victim: ${task['emergency']['victim_name']}'),
                              Text('Status: ${task['status']}'),
                              if (task['emergency']['description'] != null)
                                Text('Details: ${task['emergency']['description']}'),
                            ],
                          ),
                          trailing: task['status'] == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _acceptTask(task['id']),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _declineTask(task['id']),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
