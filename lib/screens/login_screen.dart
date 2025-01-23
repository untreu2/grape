import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../wallet_provider.dart';
import '../utils/colors.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  
  final FocusNode _apiKeyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_apiKeyFocusNode);
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiKeyFocusNode.dispose(); 
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final apiKey = _apiKeyController.text.trim();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    try {
      await walletProvider.saveApiKey(apiKey);
      await walletProvider.fetchBalance();
      if (walletProvider.balance != null &&
          walletProvider.balance != "BTC wallet not found." &&
          walletProvider.balance != "Failed to fetch balance.") {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        await walletProvider.clearApiKey();
        setState(() {
          _error = "Invalid API Key or Unable to Fetch Balance.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  
  Future<void> _launchAPIKeyPage() async {
    final Uri url = Uri.parse('https://dashboard.blink.sv/api-keys');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBackground, 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center( 
          child: SingleChildScrollView( 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                
                AnimatedTextKit(
                  animatedTexts: [
                    TyperAnimatedText(
                      'grape',
                      textStyle: TextStyle(
                        fontSize: 50.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.loginText, 
                        letterSpacing: 4.0,
                      ),
                      speed: const Duration(milliseconds: 200),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
                const SizedBox(height: 40),
                Text(
                  'Enter your Blink API Key',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: AppColors.loginText), 
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _apiKeyController,
                    focusNode: _apiKeyFocusNode, 
                    style: TextStyle(color: AppColors.loginText), 
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      labelStyle: TextStyle(color: AppColors.loginText), 
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.loginInputBorder), 
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.loginInputBorder), 
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your API key';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.loginErrorText), 
                  ),
                const SizedBox(height: 20),
                _isLoading
                    ? const SpinKitFadingCircle(
                        color: AppColors.loginText, 
                        size: 50.0,
                      )
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loginButtonBackground, 
                          minimumSize: const Size(double.infinity, 50), 
                          padding: const EdgeInsets.symmetric(vertical: 15), 
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: AppColors.loginButtonText, 
                          ),
                        ),
                      ),
                const SizedBox(height: 10), 
                TextButton(
                  onPressed: _launchAPIKeyPage,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'Get your API Key',
                    style: TextStyle(
                      color: AppColors.primaryText, 
                      fontSize: 16,
                    ),
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
