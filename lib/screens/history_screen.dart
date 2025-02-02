import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/lnparser.dart';
import '../utils/colors.dart';
import '../wallet_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

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

  Widget _buildTransactionTile(Map<String, dynamic> tx, int index) {
    final String invoice = tx["invoice"] as String;
    final int settlementAmount = tx["settlementAmount"] is int
        ? tx["settlementAmount"] as int
        : int.tryParse(tx["settlementAmount"].toString()) ?? 0;
    Color tileColor =
        settlementAmount >= 0 ? AppColors.success : AppColors.buttonText;
    final String titleText = settlementAmount >= 0 ? "Received" : "Sent";
    final int? parsedAmount = LightningInvoiceParser.getSatoshiAmount(invoice);
    final String? memo = LightningInvoiceParser.getMemo(invoice);
    String truncatedInvoice = invoice.length > 10
        ? '${invoice.substring(0, 10)}...'
        : invoice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: tileColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        title: Text(
          titleText,
          style: const TextStyle(color: AppColors.primaryText),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: invoice));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invoice copied.")),
                );
              },
              child: Text(
                "Payment Request: $truncatedInvoice",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (parsedAmount != null)
              Text(
                "Amount: $parsedAmount satoshis",
                style: const TextStyle(color: AppColors.primaryText),
              ),
            if (memo != null && memo.isNotEmpty)
              Text(
                "Memo: $memo",
                style: const TextStyle(color: AppColors.primaryText),
              ),
          ],
        ),
      ),
    );
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
                        return _buildTransactionTile(tx, index);
                      },
                    ),
    );
  }
}
