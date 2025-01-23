import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallet_provider.dart';
import '../utils/colors.dart';

void showInvoiceDialog(BuildContext context, Function(String) onInvoiceCreated) {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  FocusNode _amountFocusNode = FocusNode();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      Future.delayed(const Duration(milliseconds: 100), () {
        FocusScope.of(context).requestFocus(_amountFocusNode);
      });

      return Dialog(
        backgroundColor: AppColors.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: AppColors.dialogBorder, width: 2.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Receive some sats!',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dialogText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Consumer<WalletProvider>(
                builder: (context, walletProvider, child) {
                  if (walletProvider.lightningAddress == null) {
                    return Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primaryText,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fetching Lightning Address...',
                          style: TextStyle(
                            color: AppColors.dialogText,
                            fontSize: 16.0,
                          ),
                        ),
                      ],
                    );
                  } else if (walletProvider.lightningAddress!.startsWith('Error') ||
                      walletProvider.lightningAddress!.startsWith('API')) {
                    return Text(
                      walletProvider.lightningAddress!,
                      style: TextStyle(
                        color: AppColors.dialogErrorText,
                        fontSize: 16.0,
                      ),
                      textAlign: TextAlign.center,
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        SelectableText(
                          walletProvider.lightningAddress!,
                          style: TextStyle(
                            color: AppColors.dialogText,
                            fontSize: 18.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                },
              ),

              TextField(
                focusNode: _amountFocusNode,
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (Optional)',
                  labelStyle: TextStyle(color: AppColors.dialogText),
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
                  prefixIcon: Icon(Icons.currency_bitcoin, color: AppColors.dialogText),
                ),
                style: TextStyle(color: AppColors.dialogText, fontSize: 16.0),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _memoController,
                decoration: InputDecoration(
                  labelText: 'Memo (Optional)',
                  labelStyle: TextStyle(color: AppColors.dialogText),
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amountText = _amountController.text.trim();
                    final memoText = _memoController.text.trim();
                    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

                    int? amount = amountText.isEmpty ? null : int.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      amount = 0; 
                    }

                    await walletProvider.createInvoice(amount, memoText);

                    if (walletProvider.invoice != null) {
                      Navigator.pop(context);
                      onInvoiceCreated(walletProvider.invoice!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create invoice'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Create Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonBackground,
                    foregroundColor: AppColors.buttonText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
