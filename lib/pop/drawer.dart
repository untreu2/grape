import 'package:flutter/material.dart';
import '../utils/colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

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
            leading: Icon(Icons.settings, color: AppColors.secondaryText),
            title: Text(
              'Settings',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
