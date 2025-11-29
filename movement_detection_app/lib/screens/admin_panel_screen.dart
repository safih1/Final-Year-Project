import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminPanelScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Map<String, dynamic>> _emergencyAlerts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Load registered users (requires admin token)
      final usersResponse = await _apiService.getAllUsers();

      // Load emergency alerts (requires admin token)
      final alertsResponse = await _apiService.getAdminEmergencyAlerts();

      setState(() {
        _registeredUsers = usersResponse.cast<Map<String, dynamic>>();
        _emergencyAlerts = alertsResponse.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load admin data: $e';
        _isLoading = false;
      });
    }
  }

  String _getDisplayName(Map<String, dynamic> user) {
    return user['full_name'] ?? user['fullName'] ?? user['username'] ?? 'Unknown User';
  }

  int _getEmergencyCount(Map<String, dynamic> user) {
    return user['emergency_count'] ?? user['emergencyCount'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                widget.onLogout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                widget.onLogout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                _error,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAdminData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              widget.onLogout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Users Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registered Users',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Chip(
                    label: Text('${_registeredUsers.length} users'),
                    backgroundColor: Theme.of(context).hintColor.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_registeredUsers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        'No registered users found',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _registeredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _registeredUsers[index];
                      final displayName = _getDisplayName(user);
                      final emergencyCount = _getEmergencyCount(user);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Theme.of(context).primaryColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).hintColor,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['email'] ?? 'No email',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                'Joined: ${_formatDate(user['created_at'])}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text('$emergencyCount emergencies'),
                            backgroundColor: emergencyCount > 0
                                ? Colors.red.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: emergencyCount > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // Emergency Alerts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Emergency Alerts',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Chip(
                    label: Text('${_emergencyAlerts.length} alerts'),
                    backgroundColor: Colors.red.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_emergencyAlerts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.security,
                            size: 48,
                            color: Theme.of(context).hintColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No emergency alerts',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            'All users are safe',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _emergencyAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = _emergencyAlerts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Theme.of(context).primaryColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAlertColor(alert['status']),
                            child: Icon(
                              _getAlertIcon(alert['alert_type']),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            alert['user_name'] ?? 'Unknown User',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${alert['alert_type']?.toUpperCase()} - ${alert['status']?.toUpperCase()}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _getAlertColor(alert['status']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (alert['location_address'] != null)
                                Text(
                                  alert['location_address'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                _formatDate(alert['created_at']),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getAlertColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'resolved':
        return Colors.green;
      case 'false_alarm':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'manual':
        return Icons.touch_app;
      case 'automatic':
        return Icons.sensors;
      case 'panic':
        return Icons.warning;
      default:
        return Icons.emergency;
    }
  }
}