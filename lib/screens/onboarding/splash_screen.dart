import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import 'onboarding_screen.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    await Future.delayed(const Duration(seconds: 2));
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? hasSeenOnboarding = prefs.getBool('hasSeenOnboarding');
    
    if (!mounted) return;
    
    if (hasSeenOnboarding == true) {
      // User dah pernah buka app, terus ke Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      // First time user, pergi Onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
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
            // Logo (gantikan dengan logo anda)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                size: 70,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              'BantuNow',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Community Assistance Made Easy',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white.withOpacity(0.9),
              ),
            ),
            
            const SizedBox(height: 40),
            
            const CircularProgressIndicator(
              color: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }
}