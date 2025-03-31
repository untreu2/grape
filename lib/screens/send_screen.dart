import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../wallet_provider.dart';
import '../utils/lnparser.dart';
import '../utils/colors.dart';

enum CurrencyUnit { sats, usd }

class SendScreen extends StatefulWidget {
  final String? preFilledData;

  const SendScreen({Key? key, this.preFilledData}) : super(key: key);

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
  bool _showRipple = false;

  double? _fiatValue;
  double? _convertedAmount;
  CurrencyUnit _selectedUnit = CurrencyUnit.sats;

  final FocusNode _invoiceFocusNode = FocusNode();
  final FocusNode _lnurlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.preFilledData != null && widget.preFilledData!.isNotEmpty) {
      final data = widget.preFilledData!.trim();
      if (data.toLowerCase().startsWith('lnbc') && !data.contains('@')) {
        _paymentMethod = 'invoice';
        _invoiceController.text = data;
        _fetchInvoiceDetails();
      } else {
        _paymentMethod = 'lnurl';
        _lnurlController.text = data;
      }
    }
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

  Future<void> _updateFiatValue(int satoshis) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    double? fiat =
        await walletProvider.convertSatoshisToCurrency(satoshis, 'usd');
    setState(() {
      _fiatValue = fiat;
    });
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

  Future<void> _fetchInvoiceDetails() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() {
        _requestedAmount = null;
        _memo = null;
        _fee = null;
        _amountController.clear();
        _fiatValue = null;
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
    if (_requestedAmount != null) {
      _updateFiatValue(_requestedAmount!);
    }
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final fee = await walletProvider.probeInvoiceFee(invoice);
    setState(() {
      _fee = fee;
    });
  }

  Future<bool> _confirmFee(double fee) async {
    if (fee == 0) {
      return true;
    }
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

  Future<void> _sendPayment() async {
    FocusScope.of(context).unfocus();

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
        int amount;
        if (_selectedUnit == CurrencyUnit.sats) {
          amount = int.tryParse(_amountController.text.trim()) ?? 0;
        } else {
          double? usdAmount = double.tryParse(_amountController.text.trim());
          double? btcPrice =
              await walletProvider.convertSatoshisToCurrency(100000000, 'usd');
          if (usdAmount == null || btcPrice == null || btcPrice <= 0) {
            amount = 0;
          } else {
            amount = (usdAmount * 100000000 / btcPrice).round();
          }
        }
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
      if (walletProvider.status == "SUCCESS") {
        setState(() {
          _showRipple = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.status ?? "Unknown status"),
            backgroundColor: AppColors.sendError,
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

  void _onRippleAnimationComplete() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isInvoicePaymentDisabled = _paymentMethod == 'invoice' &&
        (_invoiceController.text.trim().isNotEmpty && _fee == null);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_paymentMethod == 'invoice' &&
                        _requestedAmount != null) ...[
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
                      if (_fiatValue != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: AutoSizeText(
                            "≈ \$${_fiatValue!.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 20,
                              color: AppColors.secondaryText,
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
                                _paymentMethod =
                                    index == 0 ? 'invoice' : 'lnurl';
                                _invoiceController.clear();
                                _lnurlController.clear();
                                _amountController.clear();
                                _memoController.clear();
                                _requestedAmount = null;
                                _memo = null;
                                _fee = null;
                                _fiatValue = null;
                                _convertedAmount = null;
                              });
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
                          if (_paymentMethod == 'invoice')
                            TextFormField(
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
                          else
                            Column(
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Amount',
                                          labelStyle: TextStyle(
                                              color: AppColors.primaryText),
                                          filled: true,
                                          fillColor: AppColors.buttonBackground,
                                          border: const OutlineInputBorder(),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: AppColors.border),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: AppColors.border),
                                          ),
                                        ),
                                        onChanged: _onAmountChanged,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter an amount';
                                          }
                                          if (double.tryParse(value) == null ||
                                              double.parse(value) <= 0) {
                                            return 'Enter a valid amount';
                                          }
                                          return null;
                                        },
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
                                        _onAmountChanged(
                                            _amountController.text);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_convertedAmount != null)
                                  Text(
                                    _selectedUnit == CurrencyUnit.sats
                                        ? "≈ \$${_convertedAmount!.toStringAsFixed(2)}"
                                        : "≈ ${_convertedAmount!.toStringAsFixed(0)} SATS",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.secondaryText,
                                    ),
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
                              onPressed:
                                  (_isLoading || isInvoicePaymentDisabled)
                                      ? null
                                      : _sendPayment,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
          if (_isLoading)
            Positioned.fill(
              child: RippleEffectContinuous(
                color: AppColors.payingloading,
              ),
            ),
          if (_showRipple)
            Positioned.fill(
              child: RippleEffect(
                onAnimationComplete: _onRippleAnimationComplete,
                color: AppColors.currencypositive,
              ),
            ),
        ],
      ),
    );
  }
}

class RippleEffect extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  final Color color;
  const RippleEffect({
    Key? key,
    required this.onAnimationComplete,
    this.color = const Color(0xFF4CAF50),
  }) : super(key: key);

  @override
  _RippleEffectState createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter:
              RipplePainter(progress: _animation.value, color: widget.color),
          child: Container(),
        );
      },
    );
  }
}

class RippleEffectContinuous extends StatefulWidget {
  final Color color;
  const RippleEffectContinuous({Key? key, required this.color})
      : super(key: key);

  @override
  _RippleEffectContinuousState createState() => _RippleEffectContinuousState();
}

class _RippleEffectContinuousState extends State<RippleEffectContinuous>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter:
              RipplePainter(progress: _animation.value, color: widget.color),
          child: Container(),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withOpacity(1 - progress)
      ..style = PaintingStyle.fill;
    double radius = progress * size.longestSide;
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
