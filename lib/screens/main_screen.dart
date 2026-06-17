// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/colors.dart';
import 'home/home_screen.dart';
import 'bantuan/post_bantuan_screen.dart';
import 'my_posts/my_posts_screen.dart';
import 'profile/profile_screen.dart';
import 'auth/login_screen.dart';
import 'chat/conversation_list_screen.dart';
import '../../services/chat_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final chatService = ChatService();
    chatService.getTotalUnreadStream().listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  void _showLoginRequired(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            const Text('Login Diperlukan'),
          ],
        ),
        content: Text(
            'Anda perlu log masuk untuk $action.\n\nLog masuk sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Masuk',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index, bool isLoggedIn) {
    if ((index == 1 || index == 2 || index == 3 || index == 4) && !isLoggedIn) {
      _showLoginRequired(
        context,
        index == 1
            ? 'post bantuan'
            : index == 2
                ? 'melihat mesej'
                : index == 3
                    ? 'melihat post anda'
                    : 'melihat profil',
      );
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PostBantuanScreen()),
      );
      return;
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ Tunjuk loading HANYA bila betul-betul tunggu — bukan bila dah ada data
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null &&
            FirebaseAuth.instance.currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ Guna currentUser sebagai fallback — lebih reliable pada startup
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;

    final screens = [
      const HomeScreen(),
      const SizedBox(),           // index 1 = Post (push, bukan tab)
      const ConversationListScreen(), // index 2 = Messages
      const MyPostsScreen(),      // index 3
      const ProfileScreen(),      // index 4
    ];

            return Scaffold(
            body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex == 1 ? 0 : _currentIndex,
          onTap: (index) => _onTabTapped(index, isLoggedIn),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add,
                    color: Colors.white, size: 22),
              ),
              label: 'Post',
            ),
            // ── Messages tab dengan unread badge ────────────────
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadCount > 99
                              ? '99+'
                              : _unreadCount.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadCount > 99
                              ? '99+'
                              : _unreadCount.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Mesej',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article),
              label: 'My Posts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
    ),
      ),
    );
      },
    );
  }
}