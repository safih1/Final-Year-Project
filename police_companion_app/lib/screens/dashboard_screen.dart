import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  final Completer<GoogleMapController> _controller = Completer();
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  List<dynamic> _tasks = [];
  Set<Marker> _markers = {};
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(34.1688, 73.2215),
    zoom: 14.4746,
  );
  
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
        _initialPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
      });
      _updateMyMarker(position.latitude, position.longitude);
      
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(_initialPosition));
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateMyMarker(double lat, double lng) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'me');
      _markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    });
  }

  Future<void> _connectWebSocket() async {
    final officerId = await _storage.read(key: 'officer_id');
    if (officerId == null) return;

    // Connect to WebSocket
    final wsUrl = 'ws://192.168.1.8:8000/ws/police/$officerId/';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen((message) {
      print('WebSocket message: $message');
      // Handle new task assignment
      _loadTasks();
      
      // Show SnackBar with alert sound
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 NEW TASK ASSIGNED! Check your dashboard'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
        ),
      );
    }, onError: (error) {
      print('WebSocket error: $error');
    });
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
    setState(() {
      // Keep 'me' marker
      final myMarker = _markers.firstWhere(
        (m) => m.markerId.value == 'me',
        orElse: () => const Marker(markerId: MarkerId('temp')),
      );
      
      _markers.clear();
      if (myMarker.markerId.value != 'temp') {
        _markers.add(myMarker);
      }

      for (var task in _tasks) {
        if (task['status'] != 'resolved' && task['emergency']['location']['latitude'] != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('task_${task['id']}'),
              position: LatLng(
                task['emergency']['location']['latitude'],
                task['emergency']['location']['longitude'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Emergency #${task['emergency']['id']}',
                snippet: task['emergency']['description'],
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _updateStatus(int taskId, String status) async {
    try {
      await _apiService.updateTaskStatus(taskId, status);
      _loadTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
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
                        margin: const EdgeInsets.all(8.0),
                        color: task['status'] == 'pending' ? Colors.red[50] : Colors.white,
                        child: ListTile(
                          title: Text('Emergency #${task['emergency']['id']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task['emergency']['description'] ?? 'No description'),
                              Text('Status: ${task['status'].toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: _buildActionButtons(task),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic task) {
    if (task['status'] == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => _updateStatus(task['id'], 'accepted'),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _updateStatus(task['id'], 'declined'),
          ),
        ],
      );
    } else if (task['status'] == 'accepted') {
      return ElevatedButton(
        onPressed: () => _updateStatus(task['id'], 'en_route'),
        child: const Text('En Route'),
      );
    } else if (task['status'] == 'en_route') {
      return ElevatedButton(
        onPressed: () => _updateStatus(task['id'], 'arrived'),
        child: const Text('Arrived'),
      );
    } else if (task['status'] == 'arrived') {
      return ElevatedButton(
        onPressed: () => _updateStatus(task['id'], 'resolved'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Resolve'),
      );
    }
    return const SizedBox.shrink();
  }
}
