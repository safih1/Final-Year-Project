/// Centralized API Configuration
/// Update ONLY these values to change all API endpoints
class ApiConfig {
  // ============================================
  // 🔧 CHANGE THESE VALUES BASED ON YOUR SETUP
  // ============================================
  
  /// Your computer's local IP address
  /// Find it by running: ipconfig (Windows) or ifconfig (Mac/Linux)
  /// Look for "IPv4 Address" under your active network adapter
  static const String _ipAddress = '192.168.1.14';  // ⬅️ CHANGE THIS TO YOUR IP
  
  /// Django server port (default: 8000)
  static const String _port = '8000';
  
  // ============================================
  // 📡 AUTOMATICALLY GENERATED URLs
  // ============================================
  
  /// Base URL for all HTTP requests
  static String get baseUrl => 'http://$_ipAddress:$_port';
  
  /// WebSocket URL for real-time updates
  static String get websocketUrl => 'ws://$_ipAddress:$_port/ws/emergency/';
  
  // ============================================
  // 🔗 API ENDPOINTS
  // ============================================
  
  // Authentication
  static String get registerUrl => '$baseUrl/api/auth/register/';
  static String get loginUrl => '$baseUrl/api/auth/login/';
  
  // Emergency
  static String get emergencyTriggerUrl => '$baseUrl/api/emergency/trigger/';
  static String get predictCombinedUrl => '$baseUrl/api/emergency/predict-combined/';
  static String get predictAudioUrl => '$baseUrl/api/emergency/predict-audio/';
  static String get predictMovementUrl => '$baseUrl/api/emergency/predict/';
  
  // Emergency Contacts CRUD
  static String get emergencyContactsUrl => '$baseUrl/api/emergency/contacts/';
  
  // Admin Routes
  static String get adminUsersUrl => '$baseUrl/api/admin/users/';
  static String get adminAlertsUrl => '$baseUrl/api/admin/alerts/';
  
  // Police Routes
  static String get policeLoginUrl => '$baseUrl/api/police/login/';
  static String get policeAlertsUrl => '$baseUrl/api/police/alerts/';
  
  // ============================================
  // 🐛 DEBUG HELPER
  // ============================================
  
  /// Prints all API configuration (useful for debugging)
  static void printConfiguration() {
    print('');
    print('╔═══════════════════════════════════════════╗');
    print('║      🌐 API CONFIGURATION LOADED         ║');
    print('╠═══════════════════════════════════════════╣');
    print('║ IP Address: $_ipAddress');
    print('║ Port: $_port');
    print('║ Base URL: $baseUrl');
    print('║ WebSocket: $websocketUrl');
    print('╚═══════════════════════════════════════════╝');
    print('');
    print('📋 Available Endpoints:');
    print('   • Register: $registerUrl');
    print('   • Login: $loginUrl');
    print('   • Emergency Trigger: $emergencyTriggerUrl');
    print('   • Combined Prediction: $predictCombinedUrl');
    print('   • Emergency Contacts: $emergencyContactsUrl');
    print('   • Admin Users: $adminUsersUrl');
    print('   • Admin Alerts: $adminAlertsUrl');
    print('');
  }
}