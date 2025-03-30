import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wallet_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/history_screen.dart';
import 'screens/receive_screen.dart';
import 'utils/colors.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => WalletProvider(),
      child: const Grape(),
    ),
  );
}

class Grape extends StatelessWidget {
  const Grape({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grape',
      theme: ThemeData(
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryText,
        ),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryText,
        hintColor: AppColors.secondaryText,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.primaryText,
          selectionColor: Color(0x40D7CCC8),
          selectionHandleColor: AppColors.primaryText,
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          const TextTheme(
            displayLarge: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText),
            titleLarge: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText),
            bodyLarge: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText),
            bodyMedium: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText),
            labelLarge: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: AppColors.buttonText),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(255, 67, 56, 46),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: AppColors.border),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
          hintStyle: TextStyle(
            color: Colors.grey[400],
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: AppColors.buttonText,
            backgroundColor: AppColors.buttonBackground,
            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
        ),
        toggleButtonsTheme: ToggleButtonsThemeData(
          selectedColor: AppColors.buttonText,
          color: AppColors.primaryText,
          fillColor: AppColors.buttonBackground,
          borderColor: AppColors.border,
          selectedBorderColor: AppColors.border,
          borderRadius: BorderRadius.circular(8.0),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
      ),
      home: const InitialScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const HistoryScreen(),
        '/invoice': (context) => const InvoicePage(),
      },
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    Future.delayed(Duration.zero, () {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      walletProvider.fetchBalance();
    });

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    bool loggedIn = await walletProvider.isLoggedIn();
    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryText),
        ),
      ),
    );
  }
}
