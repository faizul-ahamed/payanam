import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for the current platform.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const PayanamApp(),
    ),
  );
}

class PayanamApp extends StatelessWidget {
  const PayanamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: themeProvider.isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
        systemNavigationBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Payanam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const LoadingScreen(),
    );
  }
}
