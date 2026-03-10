// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.people_outline_rounded,
      title: 'Connect with Your Community',
      titleBM: 'Berhubung dengan Komuniti Anda',
      description:
          'Find people nearby who need help or can offer assistance in Kuala Terengganu.',
      descriptionBM:
          'Cari orang berhampiran yang memerlukan bantuan atau boleh menawarkan pertolongan di Kuala Terengganu.',
    ),
    OnboardingData(
      icon: Icons.location_on_outlined,
      title: 'Location-Based Matching',
      titleBM: 'Padanan Berdasarkan Lokasi',
      description:
          'Our smart algorithm matches you with the nearest helpers based on your location.',
      descriptionBM:
          'Algoritma kami memadankan anda dengan pembantu terdekat berdasarkan lokasi anda.',
    ),
    OnboardingData(
      icon: Icons.handshake_outlined,
      title: 'Help & Be Helped',
      titleBM: 'Bantu & Diberi Bantuan',
      description:
          'Request help when you need it, or offer assistance to those around you.',
      descriptionBM:
          'Mohon bantuan bila diperlukan, atau tawarkan bantuan kepada mereka di sekeliling anda.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;

    // ✅ Terus ke HomeScreen (bukan LoginScreen)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildDot(index),
              ),
            ),

            const SizedBox(height: 32),

            // Next / Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started / Mula'
                        : 'Next / Seterusnya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.backgroundBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 80,
              color: AppColors.primaryBlue,
            ),
          ),

          const SizedBox(height: 48),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            data.titleBM,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryBlue,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            data.descriptionBM,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGrey.withOpacity(0.7),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppColors.primaryBlue
            : AppColors.lightGrey,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingData {
  final IconData icon;
  final String title;
  final String titleBM;
  final String description;
  final String descriptionBM;

  OnboardingData({
    required this.icon,
    required this.title,
    required this.titleBM,
    required this.description,
    required this.descriptionBM,
  });
}