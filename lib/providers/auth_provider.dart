// lib/providers/auth_provider.dart
//
// Provider untuk manage auth state:
// - Current user (Firebase Auth)
// - Login state
// - User display name
//
// TIDAK mengubah logic dalam auth_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // ── Auth state ───────────────────────────────────────────────────────────────
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  String get userName {
    final user = _firebaseAuth.currentUser;
    if (user == null) return '';
    return user.displayName ?? user.email ?? 'User';
  }

  String get userEmail => _firebaseAuth.currentUser?.email ?? '';
  String get userUid => _firebaseAuth.currentUser?.uid ?? '';

  // ── Listen to auth state changes ─────────────────────────────────────────────
  // Notify listeners bila auth state berubah (login/logout)
  AuthProvider() {
    _firebaseAuth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  // ── Login dengan email/password ──────────────────────────────────────────────
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    final result = await _authService.signInWithEmail(email, password);
    notifyListeners();
    return result;
  }

  // ── Login dengan Google ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    notifyListeners();
    return result;
  }

  // ── Sign up ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      name: name,
      phone: phone,
    );
    notifyListeners();
    return result;
  }

  // ── Logout ───────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}