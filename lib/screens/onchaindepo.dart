import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbita/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../wallet_provider.dart';

class OnChainAddressPage extends StatefulWidget {
  const OnChainAddressPage({super.key});

  @override
  _OnChainAddressPageState createState() => _OnChainAddressPageState();
}

class _OnChainAddressPageState extends State<OnChainAddressPage> {
  @override
  void initState() {
    super.initState();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    walletProvider.createOnChainAddress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          final onChainAddress = walletProvider.onChainAddress;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: onChainAddress == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "5.000 sats fees for on-chain payments below 1.000.000 sats",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        QrImageView(
                          data: onChainAddress,
                          version: QrVersions.auto,
                          size: 300.0,
                          backgroundColor: AppColors.qrBackground,
                        ),
                        const SizedBox(height: 30),
                        SelectableText(
                          onChainAddress,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.copy,
                            color: AppColors.primaryText,
                          ),
                          label: const Text("Copy"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonBackground,
                            foregroundColor: AppColors.buttonText,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 125),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: onChainAddress),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
