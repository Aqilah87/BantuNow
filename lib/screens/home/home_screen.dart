// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('BantuNow Home'),
        backgroundColor: AppColors.primaryBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 100,
              color: AppColors.success,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to BantuNow!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You are successfully logged in',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}