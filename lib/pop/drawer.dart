import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> _logout(BuildContext context) async {
    await _storage.deleteAll();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primaryText,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'grape',
                style: TextStyle(
                  color: AppColors.background,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.history, color: AppColors.secondaryText),
            title: Text(
              'History',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: AppColors.secondaryText),
            title: Text(
              'Logout',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            onTap: () async {
              await _logout(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
