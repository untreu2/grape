import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallet_provider.dart';
import '../utils/lnparser.dart'; 
import '../utils/colors.dart'; 
import 'package:auto_size_text/auto_size_text.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({Key? key}) : super(key: key);

  @override
  _SendScreenState createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _lnurlController = TextEditingController();
  final _amountController = TextEditingController();
  String _paymentMethod = 'invoice';
  int? _requestedAmount;
  String? _memo;

  
  final FocusNode _invoiceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_invoiceFocusNode);
    });
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _lnurlController.dispose();
    _amountController.dispose();
    _invoiceFocusNode.dispose();
    super.dispose();
  }

  
  void _fetchInvoiceDetails() {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() {
        _requestedAmount = null;
        _memo = null;
        _amountController.clear();
      });
      return;
    }

    final parsedAmount = LightningInvoiceParser.getSatoshiAmount(invoice);
    final parsedMemo = LightningInvoiceParser.getMemo(invoice);

    setState(() {
      _requestedAmount = parsedAmount;
      _memo = parsedMemo;
      _amountController.text = _requestedAmount?.toString() ?? '';
    });
  }

  Future<void> _sendPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
    });

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (_paymentMethod == 'invoice') {
      final paymentRequest = _invoiceController.text.trim();
      await walletProvider.payInvoice(paymentRequest);
    } else {
      final lnurl = _lnurlController.text.trim();
      final amount = int.tryParse(_amountController.text.trim()) ?? 0;
      if (amount <= 0) {
        setState(() {
        });
        return;
      }
      await walletProvider.payLnurl(lnurl, amount);
    }

    if (walletProvider.status != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.status!),
          backgroundColor: walletProvider.status == "SUCCESS" ? AppColors.sendSuccess : AppColors.sendError,
        ),
      );
    } else {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_requestedAmount != null) ...[
Padding(
  padding: const EdgeInsets.only(bottom: 10.0),
  child: AutoSizeText(
    "${_requestedAmount} SATS",
    style: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.bold,
      color: AppColors.sendAmountText,
    ),
    maxLines: 1,
    minFontSize: 10,
    overflow: TextOverflow.ellipsis,
  ),
),
if (_memo != null && _memo!.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(bottom: 20.0),
    child: AutoSizeText(
      "$_memo",
      style: TextStyle(
        fontSize: 24,
        fontStyle: FontStyle.italic,
        color: AppColors.secondaryText,
      ),
      maxLines: 1,
      minFontSize: 10,
      overflow: TextOverflow.ellipsis,
    ),
  ),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      ToggleButtons(
                        isSelected: [
                          _paymentMethod == 'invoice',
                          _paymentMethod == 'lnurl',
                        ],
                        onPressed: (index) {
                          setState(() {
                            _paymentMethod = index == 0 ? 'invoice' : 'lnurl';
                            _invoiceController.clear();
                            _lnurlController.clear();
                            _amountController.clear();
                            _requestedAmount = null;
                            _memo = null;
                          });
                          if (index == 0) {
                            FocusScope.of(context).requestFocus(_invoiceFocusNode);
                          }
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
                            padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                            child: Text('Invoice'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                            child: Text('LNURL'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _paymentMethod == 'invoice'
                          ? TextFormField(
                              controller: _invoiceController,
                              focusNode: _invoiceFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Lightning Invoice',
                                labelStyle: TextStyle(color: AppColors.primaryText),
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                              ),
                              onChanged: (value) => _fetchInvoiceDetails(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a Lightning Invoice';
                                }
                                return null;
                              },
                            )
                          : Column(
                              children: [
                                TextFormField(
                                  controller: _lnurlController,
                                  decoration: InputDecoration(
                                    labelText: 'LNURL (someone@some.com)',
                                    labelStyle: TextStyle(color: AppColors.primaryText),
                                    border: const OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an LNURL';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Amount (sats)',
                                    labelStyle: TextStyle(color: AppColors.primaryText),
                                    border: const OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sendPayment,
                          label: const Text('Pay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
