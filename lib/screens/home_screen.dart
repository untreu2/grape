import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../wallet_provider.dart';
import 'send_screen.dart';
import 'history_screen.dart';
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
  String _selectedFiatCurrency = 'usd';
  final Map<String, String> _currencySymbols = {
    'usd': '\$',
    'eur': '€',
    'gbp': '£',
    'try': '₺',
  };
  List<Map<String, dynamic>> _lastTransactions = [];
  bool _isTransactionsLoading = true;

  @override
  void initState() {
    super.initState();
    _fiatBalance = null;
    _loadPreferences();
    _fetchBalance();
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
      _selectedFiatCurrency = prefs.getString('selectedFiatCurrency') ?? 'usd';
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
    setState(() {});
    _updateFiatBalance();
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
      _selectedFiatCurrency,
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

  String formatBalance(String? balance) {
    if (_isBTC) {
      double btcValue = (double.tryParse(balance ?? '0') ?? 0) / satoshiPerBTC;
      return btcValue.toStringAsFixed(8);
    } else {
      return balance ?? '0';
    }
  }

  String getBalanceLabel(String? balance) {
    if (_isBTC) {
      return 'BTC';
    } else {
      int satoshiValue = int.tryParse(balance ?? '0') ?? 0;
      return satoshiValue == 1 ? 'SAT' : 'SATS';
    }
  }

  Widget _buildCryptoLabel(String? balance) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _isBTC = !_isBTC;
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isBTC', _isBTC);
      },
      child: Text(
        getBalanceLabel(balance),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFiatBalance() {
    return GestureDetector(
      onTap: _toggleFiatCurrency,
      child: Column(
        children: [
          _fiatBalance != null
              ? Text(
                  '${_currencySymbols[_selectedFiatCurrency]!}${_fiatBalance!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _selectedFiatCurrency.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFiatCurrency() async {
    List<String> currencies = _currencySymbols.keys.toList();
    int currentIndex = currencies.indexOf(_selectedFiatCurrency);
    int nextIndex = (currentIndex + 1) % currencies.length;
    String nextCurrency = currencies[nextIndex];
    setState(() {
      _selectedFiatCurrency = nextCurrency;
      _fiatBalance = null;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedFiatCurrency', _selectedFiatCurrency);
    _updateFiatBalance();
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
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primaryText),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      body: SafeArea(
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
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatBalance(balance),
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildCryptoLabel(balance),
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
                        ? const Center(child: Text("No transactions found."))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TransferCard(
                                tx: _lastTransactions.first,
                                selectedFiatCurrency: _selectedFiatCurrency,
                                currencySymbols: _currencySymbols,
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
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 20.0),
                    child: Row(
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18.0),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18.0),
                            ),
                            label: const Text(
                              'Send',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
