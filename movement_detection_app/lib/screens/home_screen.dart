import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secure_step/services/background_service.dart';
import 'dart:async';
import '../widgets/app_drawer.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? loggedInUser;
  final Function(String userEmail, Map<String, String> newContact) onUpdateEmergencyContacts;
  final Function(String userEmail, String newLocation) onUpdateEmergencyData;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    this.loggedInUser,
    required this.onUpdateEmergencyContacts,
    required this.onUpdateEmergencyData,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();

  Map<String, double>? _policeLocation;
  int? _policeETA;
  bool _policeResponding = false;

  Timer? _locationUpdateTimer;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    if (widget.loggedInUser != null && widget.loggedInUser!['id'] != null) {
      _wsService.connect(widget.loggedInUser!['id']);
      _wsService.onPoliceLocationUpdate = _handlePoliceLocation;
      _wsService.onEmergencyResolved = _handleEmergencyResolved;
    }

    _startUpdateMonitor();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _locationUpdateTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startUpdateMonitor() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_lastUpdateTime != null && _policeResponding) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);

        if (timeSinceLastUpdate.inSeconds > 15) {
          _resetPoliceStatus();
        }
      }
    });
  }

  void _resetPoliceStatus() {
    setState(() {
      _policeLocation = null;
      _policeETA = null;
      _policeResponding = false;
      _lastUpdateTime = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency resolved. Police have stopped tracking.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _handlePoliceLocation(Map<String, dynamic> data) {
    setState(() {
      _policeLocation = {
        'lat': data['coordinates']['lat']?.toDouble() ?? 0.0,
        'lng': data['coordinates']['lng']?.toDouble() ?? 0.0,
      };
      _policeETA = data['eta'];
      _policeResponding = true;
      _lastUpdateTime = DateTime.now();
    });

    if (_lastUpdateTime == null ||
        DateTime.now().difference(_lastUpdateTime!).inSeconds > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Police unit responding! ETA: ${_policeETA ?? "calculating"} minutes'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleEmergencyResolved(Map<String, dynamic> data) {
    _resetPoliceStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data['message'] ?? 'Emergency has been resolved'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleNoThreat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text('Confirm No Threat',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20)),
          content: Text(
            'Are you sure there is no threat? This will notify police to stop responding.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).hintColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm - No Threat'),
              onPressed: () {
                Navigator.of(context).pop();
                _sendNoThreatMessage();
              },
            ),
          ],
        );
      },
    );
  }

  void _sendNoThreatMessage() {
    if (widget.loggedInUser != null && widget.loggedInUser!['id'] != null) {
      _wsService.sendNoThreat(userId: widget.loggedInUser!['id']);
      _resetPoliceStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No threat confirmed. Police have been notified.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _confirmAndTriggerEmergency() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text('Confirm Emergency',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20)),
          content: Text(
              'Are you sure you want to manually trigger an emergency?',
              style: Theme.of(context).textTheme.bodyLarge
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).hintColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Confirm & Trigger'),
              onPressed: () {
                Navigator.of(context).pop();
                _triggerEmergencyLogic();
              },
            ),
          ],
        );
      },
    );
  }

  void _triggerEmergencyLogic() async {
    if (widget.loggedInUser == null || widget.loggedInUser!['email'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in properly.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching location & triggering alert...')),
    );

    try {
      final position = await _getCurrentPosition();
      final double currentLat = position.latitude;
      final double currentLng = position.longitude;
      final String currentLocation =
          "Lat: ${currentLat.toStringAsFixed(5)}, Lng: ${currentLng.toStringAsFixed(5)}";

      final result = await _apiService.triggerEmergency(
        alertType: 'manual',
        address: currentLocation,
        latitude: currentLat,
        longitude: currentLng,
        description: 'Manual emergency trigger from app',
      );

      if (result['alert'] != null) {
        _wsService.sendEmergencyTrigger(
          alertId: result['alert']['id'],
          userId: widget.loggedInUser!['id'],
          userName: widget.loggedInUser!['full_name'] ??
              widget.loggedInUser!['fullName'] ??
              'Unknown User',
          location: currentLocation,
          coordinates: {
            'lat': currentLat,
            'lng': currentLng,
          },
        );

        widget.onUpdateEmergencyData(widget.loggedInUser!['email'], currentLocation);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent with your live location!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );

        print("Emergency triggered for user: ${widget.loggedInUser!['email']} at $currentLocation");
      } else {
        throw Exception('Failed to create emergency alert');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error triggering emergency: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print("Error triggering emergency: $e");
    }
  }

  void _callPolice() {
    _confirmAndTriggerEmergency();
  }

  Future<void> _startGuardianMode() async {
  try {
    // Request permissions
    final micStatus = await Permission.microphone.request();
    final locationStatus = await Permission.location.request();
    
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice activation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!locationStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for emergency alerts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Initialize and start service
    await BackgroundService().initialize();
    await BackgroundService().startService();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🛡️ Guardian Mode Activated - Say "Help" to trigger'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error starting Guardian Mode: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final String userName = widget.loggedInUser?['full_name'] ??
        widget.loggedInUser?['fullName'] ??
        widget.loggedInUser?['username'] ??
        "User";

    final List<Map<String, dynamic>> emergencyContactsRaw =
        (widget.loggedInUser?['emergencyContacts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final List<Map<String, String>> emergencyContacts = emergencyContactsRaw.map((contact) => {
      'name': contact['name']?.toString() ?? '',
      'phone': contact['phone_number']?.toString() ?? contact['phone']?.toString() ?? '',
    }).toList();

    final int emergencyCount = widget.loggedInUser?['emergency_count'] ??
        widget.loggedInUser?['emergencyCount'] ?? 0;
    final List<String> emergencyLocations = (widget.loggedInUser?['emergencyLocations'] as List?)?.cast<String>() ?? [];
    final String lastEmergencyLocation = emergencyLocations.isNotEmpty ? emergencyLocations.last : "N/A";

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: "Notifications (coming soon)",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification panel is under development.')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).hintColor.withOpacity(0.5),
              child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(
        loggedInUser: widget.loggedInUser,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_policeResponding)
                Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color: Colors.green.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_police, color: Colors.white, size: 32),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🚨 POLICE RESPONDING',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'ETA: ${_policeETA ?? "Calculating"} minutes',
                                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_policeLocation != null) ...[
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Police Location: ${_policeLocation!['lat']!.toStringAsFixed(4)}, ${_policeLocation!['lng']!.toStringAsFixed(4)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('No Threat - Cancel Alert'),
                          onPressed: _handleNoThreat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Safety Status',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Theme.of(context).hintColor, size: 28),
                          const SizedBox(width: 10),
                          Text('Emergencies Triggered: ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('$emergencyCount', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_history, color: Theme.of(context).hintColor, size: 28),
                          const SizedBox(width: 10),
                          Text('Last Emergency Location: ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(lastEmergencyLocation, style: Theme.of(context).textTheme.bodyLarge)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.contact_emergency_outlined, size: 60, color: Colors.orangeAccent),
                      const SizedBox(height: 15),
                      Text(
                        'Emergency Contacts',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      emergencyContacts.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            Text('No emergency contacts added yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/emergency_contacts');
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Manage Emergency Contacts'),
                            ),
                          ],
                        ),
                      )
                          : Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: emergencyContacts.length > 3 ? 3 : emergencyContacts.length,
                            itemBuilder: (context, index) {
                              final contact = emergencyContacts[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Theme.of(context).hintColor.withOpacity(0.3),
                                        child: Icon(Icons.person_outline, color: Theme.of(context).hintColor),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(contact['name']!,
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                                            ),
                                            Text(contact['phone']!,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (emergencyContacts.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                '+ ${emergencyContacts.length - 3} more contacts',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ),
                          const SizedBox(height: 15),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/emergency_contacts');
                            },
                            icon: const Icon(Icons.manage_accounts),
                            label: const Text('Manage All Contacts'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Add New Contact'),
                        onPressed: () {
                          Navigator.pushNamed(context, '/emergency_contacts');
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // FIXED: The problematic Call Police button
                      ElevatedButton.icon(
                        onPressed: _policeResponding ? null : _callPolice,
                        icon: const Icon(Icons.local_police),
                        label: Text(_policeResponding ? 'Police Notified' : 'Call Police'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _policeResponding ? Colors.grey : Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 60),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 15),
ElevatedButton.icon(
  onPressed: _startGuardianMode,
  icon: const Icon(Icons.shield),
  label: const Text('Activate Guardian Mode'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 60),
    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
  ),
),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}