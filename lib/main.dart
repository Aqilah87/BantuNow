// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'services/deep_link_service.dart';
import 'utils/colors.dart';
import 'screens/onboarding/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BantuNowApp());
}

class BantuNowApp extends StatefulWidget {
  const BantuNowApp({Key? key}) : super(key: key);

  @override
  State<BantuNowApp> createState() => _BantuNowAppState();
}

class _BantuNowAppState extends State<BantuNowApp> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _deepLinkService.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        title: 'BantuNow',
        debugShowCheckedModeBanner: false,
        // ✅ navigatorKey untuk deep link navigation
        navigatorKey: _deepLinkService.navigatorKey,
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
          fontFamily: 'Poppins',
          useMaterial3: false,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}