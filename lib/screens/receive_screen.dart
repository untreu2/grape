import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../wallet_provider.dart';
import '../utils/colors.dart';

enum CurrencyUnit { sats, usd }

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
  String _receiveMethod = 'lightning';

  CurrencyUnit _selectedUnit = CurrencyUnit.sats;
  double? _convertedAmount;

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
    _onAmountChanged(_amountController.text);
  }

  Future<void> _onAmountChanged(String value) async {
    double? amount = double.tryParse(value);
    if (amount == null) {
      setState(() {
        _convertedAmount = null;
      });
      return;
    }
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (_selectedUnit == CurrencyUnit.sats) {
      int sats = amount.toInt();
      double? fiat =
          await walletProvider.convertSatoshisToCurrency(sats, 'usd');
      setState(() {
        _convertedAmount = fiat;
      });
    } else {
      double? btcPrice =
          await walletProvider.convertSatoshisToCurrency(100000000, 'usd');
      if (btcPrice != null && btcPrice > 0) {
        int sats = (amount * 100000000 / btcPrice).round();
        setState(() {
          _convertedAmount = sats.toDouble();
        });
      } else {
        setState(() {
          _convertedAmount = null;
        });
      }
    }
  }

  Future<void> _updateQr() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (_receiveMethod == 'lightning') {
      if (_amountController.text.trim().isEmpty && _memoController.text.trim().isEmpty) {
        setState(() {
          _qrData = walletProvider.lightningAddress ?? '';
        });
        return;
      }

      setState(() {
        _isUpdating = true;
      });

      final amountText = _amountController.text.trim();
      int amountSats = 0;
      if (_selectedUnit == CurrencyUnit.sats) {
        amountSats = int.tryParse(amountText) ?? 0;
      } else {
        double? usdAmount = double.tryParse(amountText);
        double? btcPrice = await walletProvider.convertSatoshisToCurrency(100000000, 'usd');
        if (usdAmount == null || btcPrice == null || btcPrice <= 0) {
          amountSats = 0;
        } else {
          amountSats = (usdAmount * 100000000 / btcPrice).round();
        }
      }

      final memo = _memoController.text.trim();

      await walletProvider.createInvoice(amountSats, memo);

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
    } else {
      setState(() {
        _isUpdating = true;
      });

      await walletProvider.createOnChainAddress();

      if (walletProvider.onChainAddress != null &&
          !walletProvider.onChainAddress!.startsWith('Error') &&
          !walletProvider.onChainAddress!.contains('Failed')) {
        setState(() {
          _qrData = walletProvider.onChainAddress!;
        });
      } else {
        setState(() {
          _qrData = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.onChainAddress ?? 'Failed to create on-chain address'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
    final bool showLightningAddress =
        _receiveMethod == 'lightning' && _amountController.text.trim().isEmpty &&
        _memoController.text.trim().isEmpty;
    
    String labelText;
    if (_receiveMethod == 'lightning') {
      labelText = showLightningAddress
          ? (walletProvider.lightningAddress ?? '')
          : (walletProvider.invoice != null && walletProvider.invoice!.isNotEmpty
              ? _displayTruncatedInvoice(walletProvider.invoice!)
              : (walletProvider.lightningAddress ?? ''));
    } else {
      labelText = walletProvider.onChainAddress ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.buttonText,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            Center(
              child: ToggleButtons(
                isSelected: [
                  _receiveMethod == 'lightning',
                  _receiveMethod == 'onchain',
                ],
                onPressed: (index) {
                  setState(() {
                    _receiveMethod = index == 0 ? 'lightning' : 'onchain';
                    _amountController.clear();
                    _memoController.clear();
                    _convertedAmount = null;
                  });
                  _updateQr();
                },
                borderRadius: BorderRadius.circular(30),
                borderWidth: 2,
                selectedBorderColor: AppColors.border,
                borderColor: AppColors.border,
                selectedColor: AppColors.buttonText,
                color: AppColors.primaryText,
                fillColor: AppColors.buttonBackground,
                textStyle: Theme.of(context).textTheme.bodyLarge,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Text('Lightning'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Text('On-Chain'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            if (_receiveMethod == 'lightning')
              Row(
                children: [
                  Expanded(
                    child: TextField(
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
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<CurrencyUnit>(
                    value: _selectedUnit,
                    items: const [
                      DropdownMenuItem(
                        value: CurrencyUnit.sats,
                        child: Text("SATS"),
                      ),
                      DropdownMenuItem(
                        value: CurrencyUnit.usd,
                        child: Text("USD"),
                      ),
                    ],
                    onChanged: (newValue) {
                      setState(() {
                        _selectedUnit = newValue!;
                      });
                      _onAmountChanged(_amountController.text);
                    },
                  ),
                ],
              ),
            if (_receiveMethod == 'lightning' && _convertedAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Text(
                    _selectedUnit == CurrencyUnit.sats
                        ? "≈ \$${_convertedAmount!.toStringAsFixed(2)}"
                        : "≈ ${_convertedAmount!.toStringAsFixed(0)} SATS",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            if (_receiveMethod == 'lightning') const SizedBox(height: 16),
            if (_receiveMethod == 'lightning')
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
            if (_receiveMethod == 'onchain')
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'This is a Bitcoin on-chain address. Funds sent to this address will appear in your wallet after network confirmation.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
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
