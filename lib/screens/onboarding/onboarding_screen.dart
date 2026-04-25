// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ✅ Tambah slide privasi
  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.people_outline_rounded,
      title: 'Connect with Your Community',
      titleBM: 'Berhubung dengan Komuniti Anda',
      description: 'Find people nearby who need help or can offer assistance in Kuala Terengganu.',
      descriptionBM: 'Cari orang berhampiran yang memerlukan bantuan atau boleh menawarkan pertolongan di Kuala Terengganu.',
    ),
    OnboardingData(
      icon: Icons.location_on_outlined,
      title: 'Location-Based Matching',
      titleBM: 'Padanan Berdasarkan Lokasi',
      description: 'Our smart algorithm matches you with the nearest helpers based on your location.',
      descriptionBM: 'Algoritma kami memadankan anda dengan pembantu terdekat berdasarkan lokasi anda.',
    ),
    OnboardingData(
      icon: Icons.handshake_outlined,
      title: 'Help & Be Helped',
      titleBM: 'Bantu & Diberi Bantuan',
      description: 'Request help when you need it, or offer assistance to those around you.',
      descriptionBM: 'Mohon bantuan bila diperlukan, atau tawarkan bantuan kepada mereka di sekeliling anda.',
    ),
    // ✅ Slide baru — privasi
    OnboardingData(
      icon: Icons.shield_outlined,
      title: 'Your Privacy is Protected',
      titleBM: 'Privasi Anda Terjaga',
      description: 'Your GPS location is used only to find nearby help. It is never stored on our servers or shared with anyone.',
      descriptionBM: 'Lokasi GPS anda hanya digunakan untuk mencari bantuan berdekatan. Ia tidak disimpan di pelayan kami atau dikongsi dengan sesiapa.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text('Skip', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started / Mula' : 'Next / Seterusnya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
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
    // ✅ Highlight warna berbeza untuk slide privasi
    final isPrivacySlide = data.icon == Icons.shield_outlined;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              color: isPrivacySlide ? Colors.green.withOpacity(0.1) : AppColors.backgroundBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 80,
                color: isPrivacySlide ? Colors.green : AppColors.primaryBlue),
          ),
          const SizedBox(height: 48),
          Text(data.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(data.titleBM,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: isPrivacySlide ? Colors.green : AppColors.primaryBlue)),
          const SizedBox(height: 16),
          Text(data.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5)),
          const SizedBox(height: 8),
          Text(data.descriptionBM,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey.withOpacity(0.7), height: 1.5, fontStyle: FontStyle.italic)),
          // ✅ Extra note untuk slide privasi
          if (isPrivacySlide) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nombor telefon hanya visible kepada pengguna yang log masuk.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        color: _currentPage == index ? AppColors.primaryBlue : AppColors.lightGrey,
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