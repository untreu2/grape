import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../wallet_provider.dart';
import '../utils/lnparser.dart';
import '../utils/colors.dart';

class SendScreen extends StatefulWidget {
  final String? preFilledData;

  const SendScreen({super.key, this.preFilledData});

  @override
  _SendScreenState createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _lnurlController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String _paymentMethod = 'invoice';
  int? _requestedAmount;
  String? _memo;
  double? _fee;
  bool _isLoading = false;

  final FocusNode _invoiceFocusNode = FocusNode();
  final FocusNode _lnurlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.preFilledData != null && widget.preFilledData!.isNotEmpty) {
      final data = widget.preFilledData!.trim();
      if (data.toLowerCase().startsWith('ln') && !data.contains('@')) {
        _paymentMethod = 'invoice';
        _invoiceController.text = data;
        _fetchInvoiceDetails();
      } else if (data.contains('@')) {
        _paymentMethod = 'lnurl';
        _lnurlController.text = data;
      } else {
        _paymentMethod = 'invoice';
        _invoiceController.text = data;
        _fetchInvoiceDetails();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_paymentMethod == 'invoice') {
        FocusScope.of(context).requestFocus(_invoiceFocusNode);
      } else {
        FocusScope.of(context).requestFocus(_lnurlFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _lnurlController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _invoiceFocusNode.dispose();
    _lnurlFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmFee(double fee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.dialogBackground,
            title: Text(
              "Confirm Payment",
              style: TextStyle(color: AppColors.primaryText),
            ),
            content: Text(
              "Fee: ${fee.toStringAsFixed(0)} sats\nProceed with payment?",
              style: TextStyle(color: AppColors.secondaryText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text("No", style: TextStyle(color: AppColors.buttonText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    Text("Yes", style: TextStyle(color: AppColors.buttonText)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _fetchInvoiceDetails() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() {
        _requestedAmount = null;
        _memo = null;
        _fee = null;
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
      _fee = null;
    });
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final fee = await walletProvider.probeInvoiceFee(invoice);
    setState(() {
      _fee = fee;
    });
  }

  Future<void> _sendPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    try {
      if (_paymentMethod == 'invoice') {
        final paymentRequest = _invoiceController.text.trim();
        await walletProvider.payInvoice(paymentRequest);
      } else {
        final lnurl = _lnurlController.text.trim();
        final amount = int.tryParse(_amountController.text.trim()) ?? 0;
        if (amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please enter a valid amount."),
              backgroundColor: AppColors.sendError,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        String memo = _memoController.text.trim();
        if (memo.isEmpty) memo = "Sent from Grape!";
        await walletProvider.createAndPayLnurlInvoice(
          lnurl,
          amount,
          memo,
          _confirmFee,
        );
      }
      if (walletProvider.status != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.status!),
            backgroundColor: walletProvider.status == "SUCCESS"
                ? AppColors.sendSuccess
                : AppColors.sendError,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.sendError,
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
    final isInvoicePaymentDisabled = _paymentMethod == 'invoice' &&
        (_invoiceController.text.trim().isNotEmpty && _fee == null);
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
                            _memoController.clear();
                            _requestedAmount = null;
                            _memo = null;
                            _fee = null;
                          });
                          if (index == 0) {
                            FocusScope.of(context)
                                .requestFocus(_invoiceFocusNode);
                          } else if (index == 1) {
                            FocusScope.of(context)
                                .requestFocus(_lnurlFocusNode);
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 32.0, vertical: 12.0),
                            child: Text('Invoice'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 32.0, vertical: 12.0),
                            child: Text('Address'),
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
                                labelStyle:
                                    TextStyle(color: AppColors.primaryText),
                                filled: true,
                                fillColor: AppColors.buttonBackground,
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppColors.border),
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
                                  focusNode: _lnurlFocusNode,
                                  decoration: InputDecoration(
                                    labelText:
                                        'LN Address (e.g. someone@domain.com)',
                                    labelStyle:
                                        TextStyle(color: AppColors.primaryText),
                                    filled: true,
                                    fillColor: AppColors.buttonBackground,
                                    border: const OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a Lightning Address';
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
                                    labelStyle:
                                        TextStyle(color: AppColors.primaryText),
                                    filled: true,
                                    fillColor: AppColors.buttonBackground,
                                    border: const OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an amount';
                                    }
                                    if (int.tryParse(value) == null ||
                                        int.parse(value) <= 0) {
                                      return 'Enter a valid amount';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _memoController,
                                  decoration: InputDecoration(
                                    labelText: 'Memo (optional)',
                                    hintText: 'Sent from Grape!',
                                    labelStyle:
                                        TextStyle(color: AppColors.primaryText),
                                    filled: true,
                                    fillColor: AppColors.buttonBackground,
                                    border: const OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || isInvoicePaymentDisabled)
                              ? null
                              : _sendPayment,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.buttonText),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.currency_bitcoin,
                                  color: AppColors.secondaryText),
                          label: _isLoading
                              ? Text('Paying...')
                              : const Text('Pay'),
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
                      if (_paymentMethod == 'invoice' &&
                          _invoiceController.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _fee == null
                                ? "Estimating fee..."
                                : _fee == 1
                                    ? "1 sat"
                                    : "Fee: ${_fee!.toStringAsFixed(0)} sats",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
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
