import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../wallet_provider.dart';
import '../pop/tx.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final result = await provider.getHistory(10);
      setState(() {
        _transactions = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching history: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          "Latest transactions",
          style: TextStyle(color: AppColors.primaryText),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(
                      child: Text(
                        "No Lightning Invoices found.",
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        return TransferCard(
                          tx: tx,
                          enableInvoiceCopy: true,
                        );
                      },
                    ),
    );
  }
}
