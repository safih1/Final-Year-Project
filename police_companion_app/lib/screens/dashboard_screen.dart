import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'dart:convert';

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
  final List<Marker> _markers = [];
  LatLng _initialPosition = const LatLng(34.1688, 73.2215);

  WebSocketChannel? _channel;
  Timer? _locationTimer;
  int? _activeTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _getCurrentLocation();
    _connectWebSocket();
    _startLocationUpdates();
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

  void _startLocationUpdates() {
    // Send location every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // Update UI marker
        _updateMyMarker(position.latitude, position.longitude);
        
        // Send to backend
        await _apiService.updateLocation(position.latitude, position.longitude);
        
        print('✅ Location updated: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('❌ Location update error: $e');
      }
    });
  }

  void _updateMyMarker(double lat, double lng) {
    setState(() {
      // Remove previous location marker
      _markers.removeWhere((m) => 
        m.child is Icon && 
        (m.child as Icon).icon == Icons.my_location
      );
      
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
        print('❌ No officer ID found');
        return;
      }
      
      final wsUrl = 'ws://192.168.1.8:8000/ws/police/$officerId/';
      print('🔌 Connecting to WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen((message) {
        try {
          final data = json.decode(message);
          print('📩 WebSocket message: $data');
          
          if (data['type'] == 'new_task') {
            // New task assigned
            _handleNewTask(data);
          } else if (data['type'] == 'task_status_update') {
            // Task status changed
            _loadTasks();
          } else if (data['type'] == 'new_emergency') {
            // New emergency alert (for dashboard view)
            _loadTasks();
          }
        } catch (e) {
          print('❌ Error parsing WebSocket message: $e');
        }
      }, onError: (error) {
        print('❌ WebSocket error: $error');
      }, cancelOnError: false);
      
      print('✅ WebSocket connected');
    } catch (e) {
      print('❌ Error connecting to WebSocket: $e');
    }
  }

  void _handleNewTask(Map<String, dynamic> data) {
    _loadTasks();
    
    if (mounted) {
      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚨 NEW EMERGENCY TASK ASSIGNED!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // Task list is already visible
            },
          ),
        ),
      );
      
      // Play sound or vibration here
      // HapticFeedback.vibrate();
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _apiService.getTasks();
      setState(() {
        _tasks = tasks;
        _updateTaskMarkers();
      });
      print('✅ Loaded ${tasks.length} tasks');
    } catch (e) {
      print('❌ Error loading tasks: $e');
    }
  }

  void _updateTaskMarkers() {
    // Preserve current location marker
    Marker? myMarker;
    try {
      myMarker = _markers.firstWhere((m) => 
        m.child is Icon && 
        (m.child as Icon).icon == Icons.my_location
      );
    } catch (_) {}
    
    _markers.clear();
    if (myMarker != null) _markers.add(myMarker);
    
    // Add emergency location markers
    for (var task in _tasks) {
      if (task['emergency'] != null &&
          task['emergency']['coordinates'] != null &&
          task['emergency']['coordinates']['latitude'] != null) {
        final lat = task['emergency']['coordinates']['latitude'];
        final lng = task['emergency']['coordinates']['longitude'];
        
        _markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 60,
            height: 60,
            child: Column(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'E-${task['emergency']['id']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptTask(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'accepted');
      setState(() {
        _activeTaskId = taskId;
      });
      _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Task accepted - Location tracking active'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markEnRoute(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'en_route');
      _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚓 Marked as En Route'),
            backgroundColor: Colors.orange,
          ),
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

  Future<void> _markArrived(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'arrived');
      _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Marked as Arrived'),
            backgroundColor: Colors.blue,
          ),
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

  Future<void> _resolveTask(int taskId) async {
    try {
      await _apiService.updateTaskStatus(taskId, 'resolved');
      setState(() {
        _activeTaskId = null;
      });
      _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Emergency Resolved'),
            backgroundColor: Colors.green,
          ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'en_route':
        return Colors.blue;
      case 'arrived':
        return Colors.purple;
      case 'resolved':
        return Colors.grey;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Map section
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
          
          // Tasks section
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: _tasks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No Active Tasks',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text('You\'re all clear!'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final status = task['status'];
                        final emergency = task['emergency'];
                        
                        return Card(
                          margin: const EdgeInsets.all(8),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Task #${task['id']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  '👤 Victim: ${emergency['victim_name']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '📍 Location: ${emergency['location'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (emergency['description'] != null &&
                                    emergency['description'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'ℹ️ Details: ${emergency['description']}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                
                                // Action buttons based on status
                                if (status == 'pending')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check),
                                          label: const Text('ACCEPT'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _acceptTask(task['id']),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.close),
                                          label: const Text('DECLINE'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _declineTask(task['id']),
                                        ),
                                      ),
                                    ],
                                  ),
                                
                                if (status == 'accepted')
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.directions_car),
                                    label: const Text('EN ROUTE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 40),
                                    ),
                                    onPressed: () => _markEnRoute(task['id']),
                                  ),
                                
                                if (status == 'en_route')
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.location_on),
                                    label: const Text('ARRIVED'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 40),
                                    ),
                                    onPressed: () => _markArrived(task['id']),
                                  ),
                                
                                if (status == 'arrived')
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('RESOLVE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 40),
                                    ),
                                    onPressed: () => _resolveTask(task['id']),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}