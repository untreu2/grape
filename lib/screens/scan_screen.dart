import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'send_screen.dart';
import '../utils/colors.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _scanned = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      if (Theme.of(context).platform == TargetPlatform.android) {
        controller!.pauseCamera();
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        controller!.resumeCamera();
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_scanned) {
        _scanned = true;
        final scannedText = scanData.code ?? "";
        if (scannedText.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SendScreen(preFilledData: scannedText),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Scan failed, please try again"),
            ),
          );
          _scanned = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pop(context);
            },
            label: const Text(
              "Cancel",
              style: TextStyle(fontSize: 20),
            ),
            backgroundColor: AppColors.buttonBackground,
            foregroundColor: AppColors.buttonText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
