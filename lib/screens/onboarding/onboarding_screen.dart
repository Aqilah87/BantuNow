// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../location/select_location_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── 3 slides sahaja ───────────────────────────────────────────────
  final List<_OnboardingData> _pages = [
    _OnboardingData(
      emoji: '🤝',
      gradient: [Color(0xFF1565C0), Color(0xFF1E88E5)],
      accentColor: Color(0xFF64B5F6),
      titleEN: 'Welcome to BantuNow',
      titleBM: 'Selamat Datang ke BantuNow',
      descEN:
          'A community platform connecting people in Kuala Terengganu who need help with those who can offer it.',
      descBM:
          'Platform komuniti yang menghubungkan penduduk Kuala Terengganu yang memerlukan bantuan dengan mereka yang boleh membantu.',
      features: [
        _Feature(icon: Icons.people_alt_rounded, text: 'Post & cari bantuan komuniti'),
        _Feature(icon: Icons.location_on_rounded, text: 'Matching berdasarkan kawasan'),
        _Feature(icon: Icons.star_rounded, text: 'Rating sistem untuk kepercayaan'),
      ],
    ),
    _OnboardingData(
      emoji: '🙋',
      gradient: [Color(0xFFE65100), Color(0xFFF57C00)],
      accentColor: Color(0xFFFFB74D),
      titleEN: 'Request or Offer Help',
      titleBM: 'Minta atau Tawarkan Bantuan',
      descEN:
          'Whether you need a ride, food, medical help, or just someone to talk to — post it here and your community will respond.',
      descBM:
          'Sama ada anda perlukan tumpangan, makanan, bantuan perubatan, atau sekadar seseorang untuk berbual — post di sini dan komuniti akan membantu.',
      features: [
        _Feature(icon: Icons.emoji_transportation, text: 'Transport & tumpangan'),
        _Feature(icon: Icons.restaurant, text: 'Makanan & keperluan harian'),
        _Feature(icon: Icons.medical_services, text: 'Perubatan & kecemasan'),
      ],
    ),
    _OnboardingData(
      emoji: '🛡️',
      gradient: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      accentColor: Color(0xFF81C784),
      titleEN: 'Safe & Private',
      titleBM: 'Selamat & Peribadi',
      descEN:
          'Your privacy matters. Location is used only for matching — never stored or shared. Phone numbers are visible to logged-in users only.',
      descBM:
          'Privasi anda penting. Lokasi hanya digunakan untuk padanan — tidak disimpan atau dikongsi. Nombor telefon hanya kelihatan kepada pengguna yang log masuk.',
      features: [
        _Feature(icon: Icons.gps_off, text: 'GPS tidak disimpan di pelayan'),
        _Feature(icon: Icons.lock, text: 'Nombor telefon dilindungi'),
        _Feature(icon: Icons.verified_user, text: 'Sistem rating untuk kepercayaan'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _animController.reset();
    _animController.forward();
  }

  Future<void> _completeOnboarding() async {
    if (!mounted) return;
    // → Pergi ke SelectLocationScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationScreen()),
    );
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar — Skip ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_pages.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Skip button
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(
                          backgroundColor:
                              Colors.white.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),

              // ── PageView ─────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (_, index) =>
                      _buildPage(_pages[index]),
                ),
              ),

              // ── Bottom — dots + button ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => _buildDot(i, page.accentColor),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Next / Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: page.gradient[0],
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'Mulakan / Get Started'
                                  : 'Seterusnya / Next',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: page.gradient[0]),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.location_on_rounded
                                  : Icons.arrow_forward_rounded,
                              color: page.gradient[0],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji besar dalam circle
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: Text(data.emoji,
                    style: const TextStyle(fontSize: 64)),
              ),
            ),

            const SizedBox(height: 32),

            // Title EN
            Text(
              data.titleEN,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2),
            ),
            const SizedBox(height: 6),

            // Title BM
            Text(
              data.titleBM,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.75)),
            ),

            const SizedBox(height: 20),

            // Description
            Text(
              data.descBM,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.6),
            ),

            const SizedBox(height: 28),

            // Feature chips
            ...data.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(f.icon,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        f.text,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, Color accentColor) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Data classes ────────────────────────────────────────────────────

class _OnboardingData {
  final String emoji;
  final List<Color> gradient;
  final Color accentColor;
  final String titleEN;
  final String titleBM;
  final String descEN;
  final String descBM;
  final List<_Feature> features;

  const _OnboardingData({
    required this.emoji,
    required this.gradient,
    required this.accentColor,
    required this.titleEN,
    required this.titleBM,
    required this.descEN,
    required this.descBM,
    required this.features,
  });
}

class _Feature {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});
}