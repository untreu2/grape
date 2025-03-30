import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/lnparser.dart';
import '../utils/colors.dart';
import '../wallet_provider.dart';

class TransferCard extends StatefulWidget {
  final Map<String, dynamic> tx;
  final bool enableInvoiceCopy;

  const TransferCard({
    super.key,
    required this.tx,
    this.enableInvoiceCopy = false,
  });

  @override
  _TransferCardState createState() => _TransferCardState();
}

class _TransferCardState extends State<TransferCard> {
  double? _fiatValue;

  @override
  void initState() {
    super.initState();
    _fetchFiatValue();
  }

  @override
  void didUpdateWidget(covariant TransferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tx != oldWidget.tx) {
      _fetchFiatValue();
    }
  }

  Future<void> _fetchFiatValue() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final String invoice = widget.tx["invoice"] as String;
    final int settlementAmount = widget.tx["settlementAmount"] is int
        ? widget.tx["settlementAmount"] as int
        : int.tryParse(widget.tx["settlementAmount"].toString()) ?? 0;
    final int? parsedAmount = LightningInvoiceParser.getSatoshiAmount(invoice);
    final int amount = parsedAmount ?? settlementAmount.abs();

    try {
      double? newValue =
          await walletProvider.convertSatoshisToCurrency(amount, 'usd');
      if (newValue != null && newValue != _fiatValue) {
        setState(() {
          _fiatValue = newValue;
        });
      }
    } catch (e) {
      if (_fiatValue != null) {
        setState(() {
          _fiatValue = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String invoice = widget.tx["invoice"] as String;
    final int settlementAmount = widget.tx["settlementAmount"] is int
        ? widget.tx["settlementAmount"] as int
        : int.tryParse(widget.tx["settlementAmount"].toString()) ?? 0;
    final int? parsedAmount = LightningInvoiceParser.getSatoshiAmount(invoice);
    final String? memo = LightningInvoiceParser.getMemo(invoice);
    final int amount = parsedAmount ?? settlementAmount.abs();
    final String fiatSymbol = '\$';

    String titleText;
    if (settlementAmount >= 0) {
      titleText = "Received $amount ${amount == 1 ? 'satoshi' : 'satoshis'}";
    } else {
      titleText = "Sent $amount ${amount == 1 ? 'satoshi' : 'satoshis'}";
    }
    Color tileColor = AppColors.buttonText;

    String truncatedInvoice =
        invoice.length > 10 ? '${invoice.substring(0, 10)}...' : invoice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: tileColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        title: Text(
          titleText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.enableInvoiceCopy
                  ? () {
                      Clipboard.setData(ClipboardData(text: invoice));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invoice copied.")),
                      );
                    }
                  : null,
              child: Text(
                "Payment Request: $truncatedInvoice",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  decoration: widget.enableInvoiceCopy
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
            if (memo != null && memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Memo: $memo",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          _fiatValue != null
              ? "≈$fiatSymbol${_fiatValue!.toStringAsFixed(2)}"
              : "N/A",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: settlementAmount >= 0
                ? AppColors.currencypositive
                : AppColors.currencynegative,
          ),
        ),
      ),
    );
  }
}
