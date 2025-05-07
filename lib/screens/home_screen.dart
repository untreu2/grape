import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../wallet_provider.dart';
import 'send_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import '../pop/drawer.dart';
import '../utils/colors.dart';
import '../pop/tx.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Timer? _balanceTimer;
  Timer? _transactionsTimer;
  Timer? _priceTimer;
  bool _isBTC = false;
  static const int satoshiPerBTC = 100000000;
  double? _fiatBalance;
  List<Map<String, dynamic>> _lastTransactions = [];
  bool _isTransactionsLoading = true;

  bool _showRipple = false;
  String? _previousBalance;

  @override
  void initState() {
    super.initState();
    _fiatBalance = null;
    _loadPreferences();
    _fetchBalance().then((_) {
      _previousBalance =
          Provider.of<WalletProvider>(context, listen: false).balance;
    });
    _fetchTransactions();
    _balanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _checkBalanceChange(),
    );
    _transactionsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _fetchTransactions(),
    );
    _priceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _updateFiatBalance(),
    );
    _updateFiatBalance();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBTC = prefs.getBool('isBTC') ?? false;
    });
  }

  Future<void> _fetchBalance() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.fetchBalance();
    setState(() {
      _isLoading = false;
      _fiatBalance = null;
    });
    _updateFiatBalance();
  }

  Future<void> _checkBalanceChange() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.fetchBalance();
    String? currentBalance = walletProvider.balance;
    if (_previousBalance != null && _previousBalance != currentBalance) {
      _triggerRippleEffect();
    }
    _previousBalance = currentBalance;
    setState(() {});
    _updateFiatBalance();
  }

  void _triggerRippleEffect() {
    setState(() {
      _showRipple = true;
    });
  }

  void _onRippleAnimationComplete() {
    setState(() {
      _showRipple = false;
    });
  }

  Future<void> _fetchTransactions() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    try {
      List<Map<String, dynamic>> txs = await walletProvider.getHistory(2);
      setState(() {
        _lastTransactions = txs;
        _isTransactionsLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastTransactions = [];
        _isTransactionsLoading = false;
      });
    }
  }

  Future<void> _updateFiatBalance() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    double? fiat = await walletProvider.convertSatoshisToCurrency(
      100000000,
      'usd',
    );
    if (fiat != null) {
      final String? balanceStr = walletProvider.balance;
      if (balanceStr != null) {
        int satoshis = int.tryParse(balanceStr) ?? 0;
        double btcValue = satoshis / satoshiPerBTC;
        double newFiatBalance = btcValue * fiat;
        setState(() {
          _fiatBalance = newFiatBalance;
        });
      }
    } else {
      print("Failed to fetch BTC price from wallet provider");
      setState(() {
        _fiatBalance = null;
      });
    }
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    _transactionsTimer?.cancel();
    _priceTimer?.cancel();
    super.dispose();
  }

  String getBalanceLabel(String? balance) {
    if (_isBTC) {
      return 'BTC';
    } else {
      int satoshiValue = int.tryParse(balance ?? '0') ?? 0;
      return satoshiValue == 1 ? 'SAT' : 'SATS';
    }
  }

  Widget _buildFiatBalance() {
    final Color fiatBalanceColor = _fiatBalance != null && _fiatBalance! >= 0
        ? AppColors.currencypositive
        : AppColors.currencynegative;
    return Text(
      '\$${_fiatBalance?.toStringAsFixed(2) ?? "--"}',
      style: TextStyle(
        fontSize: 24,
        color: fiatBalanceColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final balance = walletProvider.balance;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Color cryptoBalanceColor = AppColors.primaryText;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primaryText),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            setState(() {
                              _isBTC = !_isBTC;
                            });
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('isBTC', _isBTC);
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double baseFontSize = 64;
                              double balanceNum =
                                  double.tryParse(balance ?? '0') ?? 0;
                              double displayBalance = _isBTC
                                  ? balanceNum / satoshiPerBTC
                                  : balanceNum;
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      displayBalance
                                          .toStringAsFixed(_isBTC ? 8 : 0),
                                      style: TextStyle(
                                        fontSize: baseFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: cryptoBalanceColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      getBalanceLabel(balance),
                                      style: TextStyle(
                                        fontSize: baseFontSize / 2,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(top: 20.0)),
                        _buildFiatBalance(),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  Expanded(
                    flex: 4,
                    child: _isTransactionsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _lastTransactions.isEmpty
                            ? const Center(
                                child: Text("No transactions found."))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TransferCard(
                                    tx: _lastTransactions.first,
                                    enableInvoiceCopy: false,
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "Show more...",
                                        style: TextStyle(
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                  const Spacer(flex: 3),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const ScanScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 350),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: AppColors.primaryText,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                          ),
                          label: const Text(
                            'Scan',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final clipboardData =
                                await Clipboard.getData('text/plain');
                            final text = clipboardData?.text?.trim() ?? '';
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Clipboard is empty")),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SendScreen(preFilledData: text),
                              ),
                            );
                          },
                          icon: const Icon(Icons.paste,
                              color: AppColors.primaryText),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                          ),
                          label: const Text(
                            'Paste',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/invoice');
                          },
                          icon: const Icon(
                            Icons.arrow_downward,
                            color: AppColors.primaryText,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(
                                  color: AppColors.primaryText),
                            ),
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                          ),
                          label: const Text(
                            'Receive',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SendScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: AppColors.primaryText,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                          ),
                          label: const Text(
                            'Send',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
          if (_showRipple)
            Positioned.fill(
              child: RippleEffect(
                onAnimationComplete: _onRippleAnimationComplete,
              ),
            ),
        ],
      ),
    );
  }
}

class RippleEffect extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  const RippleEffect({super.key, required this.onAnimationComplete});

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
          painter: RipplePainter(progress: _animation.value),
          child: Container(),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.currencypositive.withOpacity(1 - progress)
      ..style = PaintingStyle.fill;
    double radius = progress * size.longestSide;
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
