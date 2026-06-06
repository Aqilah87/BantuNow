// lib/screens/onboarding/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import '../main_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Check onboarding DULU — sebelum check login
    final shouldShow = await _shouldShowOnboarding();
    if (!mounted) return;

    if (shouldShow) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Onboarding dah lepas — refresh Google session kalau perlu
    if (firebaseUser != null) {
      try {
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<bool> _shouldShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final savedVersion = prefs.getString('onboarding_version');

      // Guna Firebase metadata untuk detect first install
      // creationTime akan reset bila uninstall dan install semula
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        // User tak login — check version je
        if (savedVersion != currentVersion) {
          await prefs.setString('onboarding_version', currentVersion);
          return true;
        }
        return false;
      }

      // User login — check bila account dicipta vs onboarding version
      if (savedVersion != currentVersion) {
        await prefs.setString('onboarding_version', currentVersion);
        return true;
      }

      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.people_alt_rounded,
                  size: 70, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 24),
            const Text('BantuNow',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white)),
            const SizedBox(height: 8),
            Text('Community Assistance Made Easy',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9))),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.white),
          ],
        ),
      ),
    );
  }
}