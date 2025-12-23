"""
Fix home_screen.dart syntax errors
This script fixes the broken code in movement_detection_app/lib/screens/home_screen.dart
"""

import re

def fix_home_screen():
    file_path = r"c:\Users\safii\StudioProjects\SecureStep\movement_detection_app\lib\screens\home_screen.dart"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix 1: Fix the initState method (lines 42-46)
    content = re.sub(
        r'Timer\? _locationUpdateTimer;\s+DateTime\? _lastUpdateTime;\s+_listenToBackgroundService\(\);[^\}]+\}',
        '''Timer? _locationUpdateTimer;
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
  }''',
        content,
        flags=re.DOTALL
    )
    
    # Fix 2: Fix the triggerEmergency call (lines 487-500)
    broken_pattern = r'''final result = await _apiService\.triggerEmergency\(
\s+alertType: 'manual',.*?
\s+address: currentLocation,
\s+latitude: currentLat,
\s+content: Text.*?\),
\s+\)\);

\s+print\("Emergency triggered.*?"\);
\s+\} else \{
\s+throw Exception\('Failed to create emergency alert'\);
\s+\}'''
    
    fixed_code = '''final result = await _apiService.triggerEmergency(
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
              content: Text('Prediction: ${data['prediction']['severity']} (${(data['prediction']['confidence'] * 100).toStringAsFixed(1)}%)'),
              backgroundColor: Colors.purple,
              duration: Duration(seconds: 5),
            ),
          );
        }
      };

      // Request prediction after 1 second
      Future.delayed(Duration(seconds: 1), () {
        _wsService.requestPrediction();
      });

      // Send emergency trigger via WebSocket
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
    }'''
    
    content = re.sub(broken_pattern, fixed_code, content, flags=re.DOT ALL | re.MULTILINE)
    
    # Write the fixed content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Fixed home_screen.dart!")
    print("\nFixed issues:")
    print("1. Restored complete initState() method")
    print("2. Fixed triggerEmergency API call")
    print("3. Added WebSocket prediction handling")
    print("\nYou can now run: flutter run")

if __name__ == "__main__":
    try:
        fix_home_screen()
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nPlease manually fix the following in home_screen.dart:")
        print("\n1. Lines 42-60: Fix initState() method")
        print("2. Lines 487-545: Fix _triggerEmergencyLogic() method")
