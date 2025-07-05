import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';
import '../utils/logout.dart';

void logout(BuildContext context) {
  Logout.clearStorageAndLogout(context);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedCurrency = 'USD';
  bool _isLoading = false;

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'TRY', 'JPY', 'CAD', 'AUD'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('selected_currency') ?? 'USD';
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency', _selectedCurrency);
  }

  Future<void> _updateDisplayCurrency(String currency) async {
    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _selectedCurrency = currency;
      });
      await _saveSettings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Display currency updated to $currency'),
          backgroundColor: AppColors.currencypositive,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update currency: $e'),
          backgroundColor: AppColors.currencynegative,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.primaryText),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionHeader('Display'),
                _buildCurrencySelector(),
                const SizedBox(height: 24),
                
                _buildSectionHeader('Account'),
                _buildLogoutTile(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  Widget _buildCurrencySelector() {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        leading: const Icon(Icons.attach_money, color: AppColors.primaryText),
        title: const Text(
          'Display Currency',
          style: TextStyle(color: AppColors.primaryText),
        ),
        subtitle: Text(
          _selectedCurrency,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.secondaryText),
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: AppColors.background,
                title: const Text(
                  'Select Currency',
                  style: TextStyle(color: AppColors.primaryText),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _currencies.length,
                    itemBuilder: (context, index) {
                      final currency = _currencies[index];
                      return ListTile(
                        title: Text(
                          currency,
                          style: const TextStyle(color: AppColors.primaryText),
                        ),
                        trailing: _selectedCurrency == currency
                            ? const Icon(Icons.check, color: AppColors.currencypositive)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          _updateDisplayCurrency(currency);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }





  Widget _buildLogoutTile() {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppColors.currencynegative),
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.currencynegative),
        ),
        onTap: () => logout(context),
      ),
    );
  }

}
