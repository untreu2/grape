import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Logout {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> clearStorageAndLogout(BuildContext context) async {
    try {
      await _storage.deleteAll(); 
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}

