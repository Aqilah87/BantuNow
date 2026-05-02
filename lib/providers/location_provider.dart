// lib/providers/location_provider.dart
//
// Provider untuk manage state berkaitan lokasi:
// - User area (nama + id) dari SharedPreferences
// - GPS coordinates (lat/lon) dari LocationService
// - Loading state semasa fetch location
//
// TIDAK mengubah logic dalam location_service.dart atau location_model.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {

  // ── Area state ───────────────────────────────────────────────────────────────
  String _userArea = '';
  String _userAreaId = '';

  String get userArea => _userArea;
  String get userAreaId => _userAreaId;
  bool get hasArea => _userAreaId.isNotEmpty;

  // ── GPS coordinates ──────────────────────────────────────────────────────────
  double? _userLat;
  double? _userLon;
  bool _isLoadingLocation = false;

  double? get userLat => _userLat;
  double? get userLon => _userLon;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get hasLocation => _userLat != null && _userLon != null;

  // ── Init — load area dari SharedPreferences dan fetch GPS ────────────────────
  Future<void> loadLocation() async {
    // Load area dari SharedPreferences — sama seperti dalam select_location_screen
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();

    // Fetch GPS location — sama seperti LocationService.getBestLocation()
    _isLoadingLocation = true;
    notifyListeners();

    final location = await LocationService.getBestLocation();
    if (location != null) {
      _userLat = location['lat'];
      _userLon = location['lon'];
    }

    _isLoadingLocation = false;
    notifyListeners();
  }

  // ── Save area — dipanggil selepas user pilih kawasan ────────────────────────
  // Logic sama seperti _saveLocationAndContinue() dalam select_location_screen
  Future<void> saveArea(String areaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_area_id', areaId);
    await prefs.setString('user_area_name', KualaTerengganuAreas.getAreaName(areaId));

    _userAreaId = areaId;
    _userArea = KualaTerengganuAreas.getAreaName(areaId);
    notifyListeners();

    // Reload GPS selepas area berubah
    await _reloadGps();
  }

  // ── Clear area — dipanggil bila user tukar kawasan ───────────────────────────
  Future<void> clearArea() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_area_id');
    await prefs.remove('user_area_name');

    _userArea = '';
    _userAreaId = '';
    notifyListeners();
  }

  // ── Reload area dari SharedPreferences ──────────────────────────────────────
  Future<void> reloadArea() async {
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();
  }

  // ── Reload GPS sahaja ────────────────────────────────────────────────────────
  Future<void> _reloadGps() async {
    final location = await LocationService.getBestLocation();
    if (location != null) {
      _userLat = location['lat'];
      _userLon = location['lon'];
      notifyListeners();
    }
  }
}