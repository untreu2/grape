import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../wallet_provider.dart';
import '../utils/colors.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  _InvoicePageState createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String _qrData = '';
  Timer? _debounce;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _qrData = walletProvider.lightningAddress ?? '';

    _amountController.addListener(_onInputChanged);
    _memoController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateQr();
    });
  }

  Future<void> _updateQr() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (_amountController.text.trim().isEmpty &&
        _memoController.text.trim().isEmpty) {
      setState(() {
        _qrData = walletProvider.lightningAddress ?? '';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final amountText = _amountController.text.trim();
    int? amount = amountText.isEmpty ? 0 : int.tryParse(amountText);
    if (amount == null || amount < 0) {
      amount = 0;
    }

    final memo = _memoController.text.trim();

    await walletProvider.createInvoice(amount, memo);

    if (walletProvider.invoice != null) {
      setState(() {
        _qrData = walletProvider.invoice!;
      });
    } else {
      setState(() {
        _qrData = walletProvider.lightningAddress ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create invoice'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    setState(() {
      _isUpdating = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _displayTruncatedInvoice(String invoice) {
    if (invoice.length > 5) {
      return invoice.substring(0, 5) + '...';
    }
    return invoice;
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final bool showLightningAddress = _amountController.text.trim().isEmpty &&
        _memoController.text.trim().isEmpty;
    final String labelText = showLightningAddress
        ? (walletProvider.lightningAddress ?? '')
        : (walletProvider.invoice != null && walletProvider.invoice!.isNotEmpty
            ? _displayTruncatedInvoice(walletProvider.invoice!)
            : (walletProvider.lightningAddress ?? ''));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dialogBorder, width: 2.0),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.all(8.0),
                child: _isUpdating
                    ? SizedBox(
                        height: 200,
                        width: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryText,
                          ),
                        ),
                      )
                    : (_qrData.isEmpty
                        ? SizedBox(
                            height: 200,
                            width: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryText,
                              ),
                            ),
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: AppColors.qrBackground,
                          )),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              labelText,
              style: TextStyle(
                color: AppColors.dialogText,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (Optional)',
                labelStyle: TextStyle(color: AppColors.dialogText),
                filled: true,
                fillColor: AppColors.buttonBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                prefixIcon: Icon(
                  Icons.currency_bitcoin,
                  color: AppColors.dialogText,
                ),
              ),
              style: TextStyle(color: AppColors.dialogText, fontSize: 16.0),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: 'Memo (Optional)',
                labelStyle: TextStyle(color: AppColors.dialogText),
                filled: true,
                fillColor: AppColors.buttonBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                prefixIcon: Icon(Icons.note, color: AppColors.dialogText),
              ),
              style: TextStyle(color: AppColors.dialogText, fontSize: 16.0),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_qrData.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: _qrData));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Data copied to clipboard'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: Icon(Icons.copy, color: AppColors.dialogButtonText),
              label: const Text('Copy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dialogButtonBackground,
                foregroundColor: AppColors.dialogButtonText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
