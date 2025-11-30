import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/emergency_popup.dart';
import 'dart:async';
import 'loginscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ProfileDashboard extends StatefulWidget {
  const ProfileDashboard({super.key});

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard> {
  String officerName = "Loading...";
  String badgeNumber = "Loading...";
  String officerStatus = 'Available';

  int activeIncidents = 3;
  int resolvedToday = 7;
  double responseTime = 4.2;

  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _emergencySubscription;
  
  @override
  void initState() {
    super.initState();
    _loadOfficerProfile();   // <-- NEW
    _initializeWebSocket();
  }

    Future<void> _loadOfficerProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final api = ApiService();
      final profile = await api.getProfile();

      setState(() {
        officerName = profile["full_name"] ?? "Unknown Officer";
        badgeNumber = profile["badge_number"] ?? "N/A";
        officerStatus = profile["status"] ?? "Unknown";
      });
    } catch (e) {
      print("PROFILE LOAD ERROR: $e");
    }
  }

  
  Future<void> _initializeWebSocket() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? badgeNumber = prefs.getString('badge_number');
    
    if (badgeNumber != null) {
      await _wsService.connect(badgeNumber);
      
      _emergencySubscription = _wsService.emergencyStream.listen((emergency) {
        _showEmergencyPopup(emergency);
      });
    }
  }
  
  void _showEmergencyPopup(Map<String, dynamic> emergency) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => EmergencyPopup(
          emergency: emergency,
          onClose: () {
            setState(() {
              // Refresh UI if needed
            });
          },
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _emergencySubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94a3b8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        backgroundColor: const Color(0xffef2127),
    title: const Text('Officer Dashboard'),
    actions: [
    IconButton(
    icon: const Icon(Icons.notifications),
    onPressed: () {},
    ),
    IconButton(
    icon: const Icon(Icons.logout),
    onPressed: _logout,
    ),
    ],
    ),
    body: SafeArea(
    child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Profile Header
    Card(
    child: Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
    children: [
    Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
    color: const Color(0xFF3b82f6),
    borderRadius: BorderRadius.circular(40),
    ),
    child: const Icon(
    Icons.person,
    size: 40,
    color: Colors.white,
    ),
    ),
    const SizedBox(width: 20),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
  officerName,
  style: const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
),

    const SizedBox(height: 4),
    Text(
    'Badge #$badgeNumber',
  style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF94a3b8),
  ),
),
    const SizedBox(height: 8),
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
    color: const Color(0xFF10b981).withOpacity(0.2),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFF10b981)),
    ),
    child: Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
    Icon(
    Icons.circle,
    size: 8,
    color: Color(0xFF10b981),
    ),
    SizedBox(width: 6),
    Text(
    'Available',
    style: TextStyle(
    color: Color(0xFF10b981),
    fontWeight: FontWeight.bold,
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    ),
    const SizedBox(height: 24),

      // Statistics Section
      const Text(
        'Today\'s Statistics',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 16),

      _buildStatCard(
        'Active Incidents',
        activeIncidents.toString(),
        Icons.warning,
        const Color(0xFFf59e0b),
      ),
      const SizedBox(height: 12),

      _buildStatCard(
        'Resolved Today',
        resolvedToday.toString(),
        Icons.check_circle,
        const Color(0xFF10b981),
      ),
      const SizedBox(height: 12),

      _buildStatCard(
        'Avg Response Time',
        '${responseTime.toStringAsFixed(1)} min',
        Icons.timer,
        const Color(0xFF3b82f6),
      ),
      const SizedBox(height: 24),

      // Quick Actions
      // const Text(
      //   'Quick Actions',
      //   style: TextStyle(
      //     fontSize: 20,
      //     fontWeight: FontWeight.bold,
      //     color: Colors.white,
      //   ),
      // ),
      // const SizedBox(height: 16),

      // Row(
      //   children: [
      //     Expanded(
      //       child: ElevatedButton.icon(
      //         onPressed: () {},
      //         icon: const Icon(Icons.emergency),
      //         label: const Text('Report Emergency'),
      //         style: ElevatedButton.styleFrom(
      //           backgroundColor: const Color(0xFFef4444),
      //           padding: const EdgeInsets.symmetric(vertical: 16),
      //         ),
      //       ),
      //     ),
      //     const SizedBox(width: 12),
      //     Expanded(
      //       child: ElevatedButton.icon(
      //         onPressed: () {},
      //         icon: const Icon(Icons.map),
      //         label: const Text('View Map'),
      //         style: ElevatedButton.styleFrom(
      //           padding: const EdgeInsets.symmetric(vertical: 16),
      //         ),
      //       ),
      //     ),
      //   ],
      // ),
      // const SizedBox(height: 12),

    //   SizedBox(
    //     width: double.infinity,
    //     child: ElevatedButton.icon(
    //       onPressed: () {},
    //       icon: const Icon(Icons.settings),
    //       label: const Text('Settings'),
    //       style: ElevatedButton.styleFrom(
    //         backgroundColor: const Color(0xFF475569),
    //         padding: const EdgeInsets.symmetric(vertical: 16),
    //       ),
    //     ),
    //   ),
    ],
    ),
    ),
    ),
    );
  }
}