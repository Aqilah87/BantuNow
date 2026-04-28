// lib/screens/onboarding/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
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

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // ✅ Cuba silent sign in untuk refresh Google session
    // Ini penting sebab Google Sign In session expire bila app restart
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      // User ada dalam Firebase — cuba refresh Google session secara silent
      try {
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signInSilently();

        if (googleUser != null) {
          // ✅ Berjaya refresh — update Firebase credential
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
        // Kalau googleUser null, Firebase token masih valid — teruskan je
      } catch (_) {
        // Silent fail — kalau gagal, biarkan Firebase handle sendiri
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
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
                    fontSize: 14, color: AppColors.white.withOpacity(0.9))),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.white),
          ],
        ),
      ),
    );
  }
}