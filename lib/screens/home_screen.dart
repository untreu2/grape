import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallet_provider.dart';
import '../utils/colors.dart';
import '../pop/tx.dart';
import '../pop/drawer.dart';
import 'send_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _isBTC = false;
  String? _balance;
  double? _fiatRate;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    await wallet.fetchBalance();
    final history = await wallet.getHistory(6);
    final fiat = await wallet.convertSatoshisToCurrency(100000000, 'usd');

    setState(() {
      _balance = wallet.balance;
      _transactions = history;
      _fiatRate = fiat;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double balanceValue = double.tryParse(_balance ?? '0') ?? 0;
    final displayBalance = _isBTC
        ? (balanceValue / 100000000).toStringAsFixed(8)
        : balanceValue.toStringAsFixed(0);
    final balanceUnit = _isBTC ? 'BTC' : 'SATS';
    final fiatDisplay = (_fiatRate != null && _balance != null)
        ? '\$${((balanceValue / 100000000) * _fiatRate!).toStringAsFixed(2)}'
        : '--';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
        title: const Text(
          'Grape',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isBTC = !_isBTC),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: displayBalance,
                                  style: const TextStyle(
                                    fontSize: 60,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const WidgetSpan(child: SizedBox(width: 6)),
                                TextSpan(
                                  text: balanceUnit,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fiatDisplay,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: AppColors.currencypositive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      const Text(
                        "No transactions found.",
                        style: TextStyle(color: AppColors.secondaryText),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _transactions.length + 1,
                          itemBuilder: (context, index) {
                            if (index < _transactions.length) {
                              return TransferCard(
                                tx: _transactions[index],
                                enableInvoiceCopy: false,
                              );
                            } else {
                              return Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const HistoryScreen()),
                                    );
                                  },
                                  child: const Text(
                                    "Show more",
                                    style:
                                        TextStyle(color: AppColors.primaryText),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SendScreen()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18.0),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                          left: Radius.circular(40)),
                                    ),
                                    backgroundColor: AppColors.buttonBackground,
                                    foregroundColor: AppColors.buttonText,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.arrow_upward, size: 20),
                                        SizedBox(width: 6),
                                        Text('Send',
                                            style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/invoice');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18.0),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                          right: Radius.circular(40)),
                                    ),
                                    backgroundColor: AppColors.buttonBackground,
                                    foregroundColor: AppColors.buttonText,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.arrow_downward, size: 20),
                                        SizedBox(width: 6),
                                        Text('Receive',
                                            style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: -6,
                            child: Material(
                              color: AppColors.buttonBackground,
                              shape: const CircleBorder(),
                              elevation: 6,
                              child: IconButton(
                                icon: const Icon(Icons.qr_code_scanner),
                                iconSize: 28,
                                color: AppColors.primaryText,
                                padding: const EdgeInsets.all(20),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          const ScanScreen(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        return FadeTransition(
                                            opacity: animation, child: child);
                                      },
                                      transitionDuration:
                                          const Duration(milliseconds: 350),
                                    ),
                                  );
                                },
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
    );
  }
}
