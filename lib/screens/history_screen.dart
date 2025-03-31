import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../wallet_provider.dart';
import '../pop/tx.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _limit = 10;
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;
  bool _noMoreTransactions = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final result = await provider.getHistory(_limit);
      setState(() {
        _transactions = result;
        _isLoading = false;
        if (result.isEmpty) {
          _noMoreTransactions = true;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching history: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || _noMoreTransactions) return;
    setState(() {
      _isFetchingMore = true;
      _limit += 10;
    });
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final result = await provider.getHistory(_limit);
      if (result.length == _transactions.length || result.isEmpty) {
        setState(() {
          _noMoreTransactions = true;
          _isFetchingMore = false;
        });
      } else {
        setState(() {
          _transactions = result;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching more history: $e";
        _isFetchingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            "Latest transactions",
            style: TextStyle(color: AppColors.primaryText),
          ),
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          "Latest transactions",
          style: TextStyle(color: AppColors.primaryText),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text("No more transactions"))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _transactions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                      if (_noMoreTransactions) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text("No more transactions")),
                        );
                      } else if (_isFetchingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                    final tx = _transactions[index];
                    return TransferCard(
                      tx: tx,
                      enableInvoiceCopy: true,
                    );
                  },
                ),
    );
  }
}
