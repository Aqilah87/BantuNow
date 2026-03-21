// lib/services/deep_link_service.dart

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bantuan_model.dart';
import '../screens/bantuan/bantuan_detail_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ✅ Init — listen untuk incoming deep links
  Future<void> init() async {
    // Handle link bila app SUDAH buka
    _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });

    // Handle link bila app BARU dibuka dari link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        _handleLink(initialLink);
      }
    } catch (_) {}
  }

  // ✅ Parse link dan navigate ke post
  void _handleLink(Uri uri) async {
    // Format: https://aqilah87.github.io/bantunow-links/post/{postId}
    final segments = uri.pathSegments;

    if (segments.length >= 3 && segments[segments.length - 2] == 'post') {
      final postId = segments.last;
      await _navigateToPost(postId);
    }
  }

  Future<void> _navigateToPost(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(postId)
          .get();

      if (!doc.exists) return;

      final bantuan = BantuanModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BantuanDetailScreen(
            bantuan: bantuan,
            onLoginRequired: (_) {},
            isLoggedIn: true,
          ),
        ),
      );
    } catch (_) {}
  }

  // ✅ Generate share link untuk sesuatu post
  static String generatePostLink(String postId) {
    return 'https://aqilah87.github.io/bantunow-links/post/$postId';
  }
}