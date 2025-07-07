import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../wallet_provider.dart';
import '../utils/colors.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic>? initialTxData;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.initialTxData,
  });

  @override
  _TransactionDetailScreenState createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Map<String, dynamic>? _transactionDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactionDetails();
  }

  Future<void> _loadTransactionDetails() async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final details = await walletProvider.getTransactionDetails(widget.transactionId);
      
      setState(() {
        _transactionDetails = details;
        _isLoading = false;
        if (details == null) {
          _error = "Transaction not found";
        }
      });
    } catch (e) {
      setState(() {
        _error = "Error loading transaction";
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return "Invalid date";
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return "0";
    try {
      final numAmount = num.parse(amount.toString()).abs().toInt();
      return "$numAmount sats";
    } catch (e) {
      return "0 sats";
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return AppColors.currencypositive;
      case 'PENDING':
        return Colors.orange;
      case 'FAILURE':
        return AppColors.currencynegative;
      default:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Transaction'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primaryText,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Transaction'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primaryText,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.currencynegative),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.currencynegative)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTransactionDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final tx = _transactionDetails!;
    final isReceived = tx['direction']?.toUpperCase() == 'RECEIVE';
    final amount = tx['settlementAmount'] ?? 0;
    final status = tx['status'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 48,
                    color: isReceived ? AppColors.currencypositive : AppColors.currencynegative,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReceived ? 'Received' : 'Sent',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(amount),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isReceived ? AppColors.currencypositive : AppColors.currencynegative,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Center(
              child: Column(
                children: [
                  const Text('Status', style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Center(
              child: Column(
                children: [
                  const Text('Date', style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 8),
                  Text(
                    _formatDateTime(tx['createdAt']),
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Center(
              child: Column(
                children: [
                  const Text('ID', style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: tx['id'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID copied')),
                      );
                    },
                    child: Text(
                      tx['id'] ?? 'N/A',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        decoration: TextDecoration.underline,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            if (tx['initiationVia']?['paymentRequest'] != null) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Text('Invoice', style: TextStyle(color: AppColors.secondaryText)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tx['initiationVia']['paymentRequest']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invoice copied')),
                        );
                      },
                      child: Text(
                        tx['initiationVia']['paymentRequest'],
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (tx['memo'] != null && tx['memo'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Text('Memo', style: TextStyle(color: AppColors.secondaryText)),
                    const SizedBox(height: 8),
                    Text(
                      tx['memo'],
                      style: const TextStyle(color: AppColors.primaryText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}