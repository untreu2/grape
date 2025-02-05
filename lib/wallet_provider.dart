import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class WalletProvider extends ChangeNotifier {
  final String _apiUrl = "https://api.blink.sv/graphql";
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _balance;
  String? get balance => _balance;

  String? _invoice;
  String? get invoice => _invoice;

  String? _status;
  String? get status => _status;

  bool _paymentSuccessful = false;
  bool get paymentSuccessful => _paymentSuccessful;

  Timer? _paymentTimer;
  String? _authToken;
  final Map<String, double> _exchangeRateCache = {};
  final Map<String, DateTime> _exchangeRateTimestamp = {};
  final Duration _cacheDuration = Duration(minutes: 5);

  String? _lightningAddress;
  String? get lightningAddress => _lightningAddress;

  String? _onChainAddress;
  String? get onChainAddress => _onChainAddress;

  WalletProvider() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    _authToken = await _secureStorage.read(key: 'API_KEY');
    if (_authToken != null) {
      await fetchBalance();
      await fetchLightningAddress();
    }
    notifyListeners();
  }

  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: 'API_KEY', value: apiKey);
    _authToken = apiKey;
    await fetchBalance();
    await fetchLightningAddress();
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: 'API_KEY');
    _authToken = null;
    _balance = null;
    _lightningAddress = null;
    _onChainAddress = null;
    notifyListeners();
  }

  Future<bool> isLoggedIn() async {
    _authToken = await _secureStorage.read(key: 'API_KEY');
    return _authToken != null;
  }

  Future<void> fetchBalance() async {
    if (_authToken == null) {
      _balance = "Not authenticated.";
      notifyListeners();
      return;
    }

    final query = """
    query Me {
      me {
        defaultAccount {
          wallets {
            walletCurrency
            balance
          }
        }
      }
    }
    """;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final wallets = data["data"]["me"]["defaultAccount"]["wallets"];
        for (var wallet in wallets) {
          if (wallet["walletCurrency"] == "BTC") {
            _balance = wallet["balance"].toString();
            notifyListeners();
            return;
          }
        }
        _balance = "BTC wallet not found.";
      } else {
        _balance = "Failed to fetch balance.";
      }
    } catch (e) {
      _balance = "Error: $e";
    }
    notifyListeners();
  }

  Future<void> fetchLightningAddress() async {
    if (_authToken == null) {
      _lightningAddress = "Not authenticated.";
      notifyListeners();
      return;
    }

    final query = """
    query GetUserAndGlobalData {
      me {
        username
      }
      globals {
        lightningAddressDomain
      }
    }
    """;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["data"] != null &&
            data["data"]["me"] != null &&
            data["data"]["globals"] != null) {
          final String username = data["data"]["me"]["username"];
          final String lightningDomain =
              data["data"]["globals"]["lightningAddressDomain"];
          _lightningAddress = "$username@$lightningDomain";
        } else {
          _lightningAddress = "Expected data not found in API response.";
        }
      } else if (response.statusCode == 401) {
        _lightningAddress = "Authorization Error: Check your API key.";
      } else {
        _lightningAddress = "API Error: ${response.statusCode}";
      }
    } catch (e) {
      _lightningAddress = "Error: $e";
    }
    notifyListeners();
  }

  Future<void> createInvoice(int amountSatoshis, String memo) async {
    if (_authToken == null) {
      _invoice = "Not authenticated.";
      notifyListeners();
      return;
    }

    final query = """
    mutation LnInvoiceCreate(\$input: LnInvoiceCreateInput!) {
      lnInvoiceCreate(input: \$input) {
        invoice {
          paymentRequest
          paymentHash
          paymentSecret
          satoshis
        }
        errors {
          message
        }
      }
    }
    """;

    final walletId = await getWalletId();
    if (walletId == null) {
      _invoice = "BTC wallet not found.";
      notifyListeners();
      return;
    }

    final variables = {
      "input": {
        "amount": amountSatoshis,
        "walletId": walletId,
        "memo": memo.isNotEmpty ? memo : ""
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query, "variables": variables}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["data"]["lnInvoiceCreate"]["errors"] != null &&
            data["data"]["lnInvoiceCreate"]["errors"].length > 0) {
          _invoice = data["data"]["lnInvoiceCreate"]["errors"][0]["message"];
        } else {
          _invoice =
              data["data"]["lnInvoiceCreate"]["invoice"]["paymentRequest"];
        }
      } else {
        _invoice = "Failed to create invoice.";
      }
    } catch (e) {
      _invoice = "Error: $e";
    }
    notifyListeners();
  }

  Future<String?> getWalletId() async {
    if (_authToken == null) {
      return null;
    }

    final query = """
    query Me {
      me {
        defaultAccount {
          wallets {
            id
            walletCurrency
            balance
          }
        }
      }
    }
    """;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final wallets = data["data"]["me"]["defaultAccount"]["wallets"];
        for (var wallet in wallets) {
          if (wallet["walletCurrency"] == "BTC") {
            return wallet["id"];
          }
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> payInvoice(String paymentRequest) async {
    if (_authToken == null) {
      _status = "Not authenticated.";
      notifyListeners();
      return;
    }

    final query = """
    mutation LnInvoicePaymentSend(\$input: LnInvoicePaymentInput!) {
      lnInvoicePaymentSend(input: \$input) {
        status
        errors {
          message
          path
          code
        }
      }
    }
    """;

    final walletId = await getWalletId();
    if (walletId == null) {
      _status = "BTC wallet not found.";
      notifyListeners();
      return;
    }

    final variables = {
      "input": {"paymentRequest": paymentRequest, "walletId": walletId}
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query, "variables": variables}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["data"]["lnInvoicePaymentSend"]["errors"] != null &&
            data["data"]["lnInvoicePaymentSend"]["errors"].length > 0) {
          _status = data["data"]["lnInvoicePaymentSend"]["errors"][0]["message"];
        } else {
          _status = data["data"]["lnInvoicePaymentSend"]["status"];
        }
      } else {
        _status = "Failed to send payment.";
      }
    } catch (e) {
      _status = "Error: $e";
    }
    notifyListeners();
  }

  Future<void> payLnurl(String lnurl, int amountSatoshis) async {
    if (_authToken == null) {
      _status = "Not authenticated.";
      notifyListeners();
      return;
    }

    final query = """
    mutation LnurlPaymentSend(\$input: LnurlPaymentSendInput!) {
      lnurlPaymentSend(input: \$input) {
        status
        errors {
          code
          message
          path
        }
      }
    }
    """;

    final walletId = await getWalletId();
    if (walletId == null) {
      _status = "BTC wallet not found.";
      notifyListeners();
      return;
    }

    final variables = {
      "input": {"walletId": walletId, "amount": amountSatoshis, "lnurl": lnurl}
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query, "variables": variables}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["data"]["lnurlPaymentSend"]["errors"] != null &&
            data["data"]["lnurlPaymentSend"]["errors"].length > 0) {
          _status = data["data"]["lnurlPaymentSend"]["errors"][0]["message"];
        } else {
          _status = data["data"]["lnurlPaymentSend"]["status"];
        }
      } else {
        _status = "Failed to send LNURL payment.";
      }
    } catch (e) {
      _status = "Error: $e";
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getHistory(int count) async {
    if (_authToken == null) {
      return [];
    }

    final query = """
    query PaymentsWithProof(\$first: Int) {
      me {
        defaultAccount {
          transactions(first: \$first) {
            edges {
              node {
                initiationVia {
                  ... on InitiationViaLn {
                    paymentRequest
                  }
                }
                settlementAmount
                status
              }
            }
          }
        }
      }
    }
    """;

    final variables = {"first": count};

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query, "variables": variables}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> transactions =
            data["data"]["me"]["defaultAccount"]["transactions"]["edges"];
        List<Map<String, dynamic>> txList = [];

        for (var tx in transactions) {
          final node = tx["node"];
          final initiationVia = node["initiationVia"];
          if (initiationVia != null && initiationVia["paymentRequest"] != null) {
            txList.add({
              "invoice": initiationVia["paymentRequest"],
              "settlementAmount": node["settlementAmount"],
              "status": node["status"],
            });
          }
        }
        return txList;
      } else {
        print("Failed to fetch transaction history. Status code: ${response.statusCode}");
        print("Response: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching transaction history: $e");
      return [];
    }
  }

  void startPaymentCheck(String invoice) {
    if (_paymentTimer != null && _paymentTimer!.isActive) return;
    _paymentTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_authToken == null) {
        stopPaymentCheck();
        return;
      }
      bool isPaid = await checkPaymentStatus(invoice);
      if (isPaid) {
        _paymentSuccessful = true;
        notifyListeners();
        stopPaymentCheck();
      }
    });
  }

  void stopPaymentCheck() {
    if (_paymentTimer != null) {
      _paymentTimer!.cancel();
      _paymentTimer = null;
    }
  }

  Future<bool> checkPaymentStatus(String paymentRequest) async {
    if (_authToken == null) return false;

    final Map<String, dynamic> requestBody = {
      "query": """
        query PaymentsWithProof(\$first: Int) {
          me {
            defaultAccount {
              transactions(first: \$first) {
                edges {
                  node {
                    initiationVia {
                      ... on InitiationViaLn {
                        paymentRequest
                      }
                    }
                    settlementAmount
                    status
                  }
                }
              }
            }
          }
        }
      """,
      "variables": {"first": 10},
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final transactions = responseData['data']['me']['defaultAccount']['transactions']['edges'];
        for (var transaction in transactions) {
          if (transaction['node']['initiationVia']['paymentRequest'] == paymentRequest &&
              transaction['node']['status'] == 'SUCCESS') {
            return true;
          }
        }
      }
    } catch (e) {
      print("Error checking payment status: $e");
    }
    return false;
  }

  Future<double?> convertSatoshisToCurrency(int satoshis, String currency) async {
    try {
      double? btcPrice = await _fetchBtcPrice(currency);
      if (btcPrice == null) return null;
      double btcAmount = satoshis / 100000000;
      double fiatAmount = btcAmount * btcPrice;
      return fiatAmount;
    } catch (e) {
      print("Error converting satoshis to $currency: $e");
      return null;
    }
  }

  Future<int?> convertCurrencyToSatoshis(double amount, String currency) async {
    try {
      double? btcPrice = await _fetchBtcPrice(currency);
      if (btcPrice == null) return null;
      double btcAmount = amount / btcPrice;
      int satoshis = (btcAmount * 100000000).round();
      return satoshis;
    } catch (e) {
      print("Error converting $currency to satoshis: $e");
      return null;
    }
  }

  Future<double?> _fetchBtcPrice(String currency) async {
    try {
      if (_exchangeRateCache.containsKey(currency)) {
        DateTime fetchedTime = _exchangeRateTimestamp[currency]!;
        if (DateTime.now().difference(fetchedTime) < _cacheDuration) {
          return _exchangeRateCache[currency];
        }
      }
      final String apiUrl =
          'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=$currency';
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['bitcoin'] != null && data['bitcoin'][currency] != null) {
          double price = (data['bitcoin'][currency] as num).toDouble();
          _exchangeRateCache[currency] = price;
          _exchangeRateTimestamp[currency] = DateTime.now();
          return price;
        }
      } else {
        print("Failed to fetch BTC price from CoinGecko: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching BTC price from CoinGecko: $e");
    }
    return null;
  }

  Future<void> createOnChainAddress() async {
    if (_authToken == null) {
      _onChainAddress = "Not authenticated.";
      notifyListeners();
      return;
    }

    final walletId = await getWalletId();
    if (walletId == null) {
      _onChainAddress = "BTC wallet not found.";
      notifyListeners();
      return;
    }

    final query = """
    mutation onChainAddressCreate(\$input: OnChainAddressCreateInput!) {
      onChainAddressCreate(input: \$input) {
        address
        errors {
          message
        }
      }
    }
    """;

    final variables = {
      "input": {
        "walletId": walletId,
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": _authToken!,
        },
        body: jsonEncode({"query": query, "variables": variables}),
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data["data"]["onChainAddressCreate"];
        if (result["errors"] != null && result["errors"].length > 0) {
          _onChainAddress = "Error: ${result["errors"][0]["message"]}";
        } else {
          _onChainAddress = result["address"];
        }
      } else {
        _onChainAddress =
            "Failed to create on-chain address. Status Code: ${response.statusCode}";
      }
    } catch (e) {
      _onChainAddress = "Error: $e";
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stopPaymentCheck();
    super.dispose();
  }
}
