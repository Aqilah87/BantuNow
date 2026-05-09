// lib/providers/location_provider.dart
//
// Provider untuk manage state lokasi dalam aplikasi:
// - Simpan kawasan user (SharedPreferences)
// - Simpan koordinat GPS (lat/lon)
// - Control loading state semasa ambil lokasi
//
// Provider ini TIDAK handle logic GPS secara direct,
// tetapi menggunakan LocationService sebagai service layer.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {

  // ────────────────────────────────────────────────────────────────
  // AREA STATE (Kawasan user)
  // ────────────────────────────────────────────────────────────────
  String _userArea = '';      // Nama kawasan (contoh: "Gong Badak")
  String _userAreaId = '';    // ID kawasan (contoh: "KT01")

  String get userArea => _userArea;
  String get userAreaId => _userAreaId;

  // Check sama ada user dah pilih kawasan
  bool get hasArea => _userAreaId.isNotEmpty;

  // ────────────────────────────────────────────────────────────────
  // GPS STATE (Koordinat user)
  // ────────────────────────────────────────────────────────────────
  double? _userLat;   // Latitude
  double? _userLon;   // Longitude

  bool _isLoadingLocation = false; // Indicator loading

  double? get userLat => _userLat;
  double? get userLon => _userLon;

  bool get isLoadingLocation => _isLoadingLocation;

  // Check sama ada location tersedia
  bool get hasLocation => _userLat != null && _userLon != null;

  // ────────────────────────────────────────────────────────────────
  // INIT FUNCTION
  //
  // Function utama untuk:
  //   1. Load kawasan dari local storage
  //   2. Fetch lokasi GPS
  // ────────────────────────────────────────────────────────────────
  Future<void> loadLocation() async {

    // STEP 1: Load kawasan dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';

    // Notify UI untuk update data kawasan
    notifyListeners();

    // STEP 2: Fetch lokasi GPS / fallback location
    _isLoadingLocation = true;
    notifyListeners();

    final location = await LocationService.getBestLocation();

    if (location != null) {
      _userLat = location['lat'];
      _userLon = location['lon'];
    }

    // Stop loading
    _isLoadingLocation = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────
  // SAVE AREA
  //
  // Dipanggil bila user pilih kawasan baru
  // ────────────────────────────────────────────────────────────────
  Future<void> saveArea(String areaId) async {

    final prefs = await SharedPreferences.getInstance();

    // Simpan ke local storage
    await prefs.setString('user_area_id', areaId);
    await prefs.setString(
      'user_area_name',
      KualaTerengganuAreas.getAreaName(areaId),
    );

    // Update state dalam app
    _userAreaId = areaId;
    _userArea = KualaTerengganuAreas.getAreaName(areaId);

    notifyListeners();

    // Reload GPS sebab kawasan berubah
    await _reloadGps();
  }

  // ────────────────────────────────────────────────────────────────
  // CLEAR AREA
  //
  // Digunakan bila user tukar kawasan
  // ────────────────────────────────────────────────────────────────
  Future<void> clearArea() async {

    final prefs = await SharedPreferences.getInstance();

    // Remove data dari local storage
    await prefs.remove('user_area_id');
    await prefs.remove('user_area_name');

    // Reset state
    _userArea = '';
    _userAreaId = '';

    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────
  // RELOAD AREA SAHAJA
  //
  // Refresh data kawasan tanpa ganggu GPS
  // ────────────────────────────────────────────────────────────────
  Future<void> reloadArea() async {

    final prefs = await SharedPreferences.getInstance();

    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';

    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────
  // RELOAD GPS (PRIVATE FUNCTION)
  //
  // Ambil semula lokasi user menggunakan LocationService
  // ────────────────────────────────────────────────────────────────
  Future<void> _reloadGps() async {

    final location = await LocationService.getBestLocation();

    if (location != null) {
      _userLat = location['lat'];
      _userLon = location['lon'];

      notifyListeners();
    }
  }
}