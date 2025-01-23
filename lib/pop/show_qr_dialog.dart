import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../wallet_provider.dart'; 
import '../utils/colors.dart'; 

void showQrDialog(BuildContext context, String invoice) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PaymentDialog(invoice: invoice),
  );
}

class PaymentDialog extends StatefulWidget {
  final String invoice;
  const PaymentDialog({Key? key, required this.invoice}) : super(key: key);

  @override
  _PaymentDialogState createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late WalletProvider _walletProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walletProvider = Provider.of<WalletProvider>(context, listen: false);
      _walletProvider.startPaymentCheck(widget.invoice);

      _walletProvider.addListener(_paymentListener);
    });
  }

  void _paymentListener() {
    if (_walletProvider.paymentSuccessful) {
      _walletProvider.removeListener(_paymentListener);
      
      Navigator.of(context).pop();
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment Successful!'),
          backgroundColor: AppColors.success, 
        ),
      );
    }
  }

  @override
  void dispose() {
    _walletProvider.stopPaymentCheck();
    _walletProvider.removeListener(_paymentListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: AppColors.dialogBorder, width: 2.0), 
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan to Pay',
                  style: TextStyle(
                    fontSize: 20.0, 
                    fontWeight: FontWeight.bold,
                    color: AppColors.dialogText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.dialogBorder, width: 2.0),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: QrImageView(
                    data: widget.invoice,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: AppColors.qrBackground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.invoice));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Invoice copied to clipboard'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, color: AppColors.qrIconColor), 
                    label: const Text('Copy Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dialogButtonBackground,
                      foregroundColor: AppColors.dialogButtonText,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (walletProvider.paymentSuccessful)
                  Text(
                    'Payment Successful!',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 16,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
