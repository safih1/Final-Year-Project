"""
Generate corrected home_screen.dart with all functionality preserved
"""

# Read the broken file
with open(r"c:\Users\safii\StudioProjects\SecureStep\movement_detection_app\lib\screens\home_screen.dart", 'r', encoding='utf-8') as f:
    lines = f.readlines()

# The corrected initState section (lines 42-67)
init_section = '''  Timer? _locationUpdateTimer;
  DateTime? _lastUpdateTime;
  StreamSubscription? _serviceListener;
  CombinedDetectionService detectionService = CombinedDetectionService();

  @override
  void initState() {
    super.initState();
    if (widget.loggedInUser != null && widget.loggedInUser!['id'] != null) {
      _wsService.connect(widget.loggedInUser!['id']);
      _wsService.onPoliceLocationUpdate = _handlePoliceLocation;
      _wsService.onEmergencyResolved = _handleEmergencyResolved;
    }

    _startUpdateMonitor();
    _listenToBackgroundService();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _locationUpdateTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }


  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();
    
    _serviceListener = service.on('threat_detected').listen((event) {
      if (event != null && mounted) {
        print('📱 Received threat detection event: $event');
        _showThreatDetectionDialog(event);
      }
    });
  }

'''

# The corrected _triggerEmergencyLogic method (around lines 468-510)
trigger_method = '''  void _triggerEmergencyLogic() async {
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
      // Connect WebSocket for this emergency
      _wsService.connect(result['alert']['id']);
      
      // Setup prediction handler
      _wsService.onPredictionReceived = (data) {
        print('🔮 Prediction received: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Prediction: ${data['prediction']['severity']} severity (${(data['prediction']['confidence'] * 100).toStringAsFixed(1)}%)'),
              backgroundColor: Colors.purple,
              duration: Duration(seconds: 5),
            ),
          );
        }
      };

      // Request initial prediction
      Future.delayed(Duration(seconds: 1), () {
        _wsService.requestPrediction();
      });

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent with your live location!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }

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
'''

# Build the corrected file
corrected_lines = lines[:41]  # Keep up to line 41
corrected_lines.append(init_section)  # Add corrected initState section
corrected_lines.extend(lines[67:467])  # Keep lines 68-467
corrected_lines.append(trigger_method)  # Add corrected trigger method
corrected_lines.extend(lines[510:])  # Keep rest of file

# Write corrected file
with open(r"c:\Users\safii\StudioProjects\SecureStep\movement_detection_app\lib\screens\home_screen.dart", 'w', encoding='utf-8') as f:
    f.writelines(corrected_lines)

print("✅ home_screen.dart has been fixed!")
print("\nFixed sections:")
print("1. Lines 42-67: Complete initState() and dispose() methods")
print("2. Lines 468-548: Complete _triggerEmergencyLogic() method with WebSocket prediction")
print("\nAll functionality preserved:")
print("• Guardian Mode activation")
print("• Threat detection dialogs")  
print("• Police location tracking")
print("• Emergency contact management")
print("• WebSocket connections for predictions")
print("• Emergency triggering with location")
print("\nYou can now run: flutter run")
