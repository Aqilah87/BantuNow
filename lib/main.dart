// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'providers/bantuan_provider.dart';
import 'providers/location_provider.dart'; // ✅ tambah
import 'providers/auth_provider.dart';     // ✅ tambah
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'utils/colors.dart';
import 'screens/onboarding/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Tunggu Firebase Auth fully restore cached user sebelum app launch
  await FirebaseAuth.instance.authStateChanges().first;

  runApp(const BantuNowApp());
}

class BantuNowApp extends StatefulWidget {
  const BantuNowApp({Key? key}) : super(key: key);

  @override
  State<BantuNowApp> createState() => _BantuNowAppState();
}

class _BantuNowAppState extends State<BantuNowApp> {
  final _deepLinkService = DeepLinkService();
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _deepLinkService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => BantuanProvider()),
        // ✅ Register LocationProvider
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        // ✅ Register AuthProvider
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'BantuNow',
        debugShowCheckedModeBanner: false,
        navigatorKey: _deepLinkService.navigatorKey,
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
          fontFamily: 'Poppins',
          useMaterial3: false,
        ),
        home: const SplashScreen(),
        builder: (context, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notificationService.init(_deepLinkService.navigatorKey!);
          });
          return child!;
        },
      ),
    );
  }
}