import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../wallet_provider.dart';
import '../pop/show_qr_dialog.dart';
import '../pop/show_invoice_dialog.dart';
import '../screens/send_screen.dart';
import '../utils/colors.dart'; 
import '../pop/drawer.dart'; 



class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Timer? _balanceTimer;
  ConfettiController? _confettiController;
  String? _previousBalance;
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

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _fetchBalance();

    
    _balanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkBalanceChange();
    });
  }

  Future<void> _fetchBalance() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.fetchBalance();
    setState(() {
      _isLoading = false;
      _previousBalance = walletProvider.balance;
    });

    
    _convertBalanceToFiat(walletProvider.balance, _selectedFiatCurrency);
  }

  Future<void> _checkBalanceChange() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.fetchBalance();

    if (_previousBalance != null && _previousBalance != walletProvider.balance) {
      _confettiController?.play(); 

      
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 500); 
      }
    }

    setState(() {
      _previousBalance = walletProvider.balance;
    });

    
    _convertBalanceToFiat(walletProvider.balance, _selectedFiatCurrency);
  }

  
  Future<void> _convertBalanceToFiat(String? balance, String currency) async {
    if (balance == null) {
      setState(() {
        _fiatBalance = null;
      });
      return;
    }

    int satoshis = int.tryParse(balance) ?? 0;
    if (satoshis == 0) {
      setState(() {
        _fiatBalance = 0.0;
      });
      return;
    }

    
    double? fiatAmount = await Provider.of<WalletProvider>(context, listen: false)
        .convertSatoshisToCurrency(satoshis, currency);

    setState(() {
      _fiatBalance = fiatAmount;
    });
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    _confettiController?.dispose();
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
      onTap: () {
        setState(() {
          _isBTC = !_isBTC;
        });
      },
      child: Text(
        getBalanceLabel(balance),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  
  Widget _buildFiatBalance() {
    return GestureDetector(
      onTap: () {
        _toggleFiatCurrency();
      },
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
              : const Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 24,
                    color: AppColors.error, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            _selectedFiatCurrency.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.success, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  
  void _toggleFiatCurrency() {
    List<String> currencies = _currencySymbols.keys.toList();
    int currentIndex = currencies.indexOf(_selectedFiatCurrency);
    int nextIndex = (currentIndex + 1) % currencies.length;
    String nextCurrency = currencies[nextIndex];

    setState(() {
      _selectedFiatCurrency = nextCurrency;
    });
    _convertBalanceToFiat(Provider.of<WalletProvider>(context, listen: false).balance, nextCurrency);
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isBTC = !_isBTC;
                            });
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
                        const SizedBox(height: 20),
                        
                        _buildFiatBalance(),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showInvoiceDialog(context, (invoice) {
                            showQrDialog(context, invoice);
                          });
                        },
                        icon: const Icon(
                          Icons.arrow_downward,
                          color: AppColors.primaryText, 
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18.0),
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
                            MaterialPageRoute(builder: (context) => const SendScreen()),
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: AppColors.primaryText, 
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18.0),
                        ),
                        label: const Text(
                          'Send',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
              ],
              
            ),
            
          ),

          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 10,
              gravity: 0.1,
              colors: [AppColors.confettiColor], 
            ),
          ),
        ],
      ),
    );
  }
}
