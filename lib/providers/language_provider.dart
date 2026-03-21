// lib/providers/language_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  bool _isMalay = true; // Default: Bahasa Melayu

  bool get isMalay => _isMalay;
  AppStrings get strings => AppStrings(isMalay: _isMalay);

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _isMalay = prefs.getBool('is_malay') ?? true;
    notifyListeners();
  }

  Future<void> setMalay() async {
    _isMalay = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_malay', true);
    notifyListeners();
  }

  Future<void> setEnglish() async {
    _isMalay = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_malay', false);
    notifyListeners();
  }

  Future<void> toggle() async {
    _isMalay = !_isMalay;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_malay', _isMalay);
    notifyListeners();
  }
}