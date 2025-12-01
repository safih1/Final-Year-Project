import 'package:flutter/material.dart';
import 'secure_step_app.dart';
import 'config/api_config.dart';  // ✅ IMPORT CONFIG

void main() {
  // ✅ PRINT API CONFIGURATION ON STARTUP (FOR DEBUGGING)
  ApiConfig.printConfiguration();
  
  runApp(const SecureStepApp());
}