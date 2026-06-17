// lib/providers/bantuan_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bantuan_model.dart';
import '../models/location_model.dart';
import '../services/bantuan_service.dart';
import '../services/geospatial_service.dart';
import '../services/location_service.dart';

class BantuanProvider extends ChangeNotifier {
  final BantuanService _bantuanService = BantuanService();

  // ── User location & area ──────────────────────────────────────────
  String _userArea = '';
  String _userAreaId = '';
  double? _userLat;
  double? _userLon;

  // GPS auto-detect state
  bool _isDetectingGps = false;
  bool _gpsDetected = false;       // GPS berjaya detect
  bool _gpsFromAuto = false;       // True = dari auto GPS, false = manual

  String get userArea => _userArea;
  String get userAreaId => _userAreaId;
  double? get userLat => _userLat;
  double? get userLon => _userLon;
  bool get isDetectingGps => _isDetectingGps;
  bool get gpsDetected => _gpsDetected;
  bool get gpsFromAuto => _gpsFromAuto;

  // ── Filter state ──────────────────────────────────────────────────
  String _selectedType = 'all';
  Set<String> _selectedCategories = {};
  bool _filterByArea = false;

  String get selectedType => _selectedType;
  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
  bool get filterByArea => _filterByArea;

  // ── Sort state ────────────────────────────────────────────────────
  bool _sortByNearest = false;
  bool _sortByRanking = false;

  bool get sortByNearest => _sortByNearest;
  bool get sortByRanking => _sortByRanking;

  // ── Best Match Criteria ───────────────────────────────────────────
  double _bestMatchRadiusKm = 0;
  String _bestMatchType = 'all';
  bool _bestMatchRequireAvailable = false;

  double get bestMatchRadiusKm => _bestMatchRadiusKm;
  String get bestMatchType => _bestMatchType;
  bool get bestMatchRequireAvailable => _bestMatchRequireAvailable;

  bool get hasBestMatchCriteria =>
      _bestMatchRadiusKm > 0 ||
      _bestMatchType != 'all' ||
      _bestMatchRequireAvailable ||
      _selectedCategories.isNotEmpty;

  // ── Stream ────────────────────────────────────────────────────────
  Stream<List<BantuanModel>> get bantuanStream =>
      _bantuanService.getBantuanStream(
        type: _selectedType == 'all' ? null : _selectedType,
      );

  // ── Init — auto GPS detect ────────────────────────────────────────
  // 1. Load kawasan dari SharedPreferences (instant)
  // 2. Auto detect GPS → auto-set kawasan terdekat kalau belum ada
  // 3. Kalau GPS gagal → fallback ke saved area coordinates
  Future<void> loadUserAreaAndLocation() async {
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();

    // Start GPS detection
    _isDetectingGps = true;
    notifyListeners();

    try {
      final gps = await LocationService.getCurrentLocation();

        if (gps != null) {
        _gpsDetected = true;

        // Sentiasa simpan GPS coordinates untuk Nearest/Best Match
        _userLat = gps.latitude;
        _userLon = gps.longitude;

        // Guna GPS untuk kawasan HANYA kalau user belum pilih kawasan manual

        // Auto-set kawasan terdekat HANYA kalau user belum pilih kawasan
        if (_userAreaId.isEmpty) {
          final nearest = LocationService.getNearestArea(
            gps.latitude,
            gps.longitude,
          );
          if (nearest != null) {
            _userArea = nearest.name;
            _userAreaId = nearest.id;
            _gpsFromAuto = true;

            // Simpan ke SharedPreferences
            await prefs.setString('user_area_id', nearest.id);
            await prefs.setString('user_area_name', nearest.name);
          }
        }
      } else {
        // GPS gagal → fallback ke saved area coordinates
        _gpsDetected = false;
        final areaCoords = await LocationService.getAreaCoordinates();
        if (areaCoords != null) {
          _userLat = areaCoords['lat'];
          _userLon = areaCoords['lon'];
        }
      }
    } catch (_) {
      // Silent fail — guna fallback
      final areaCoords = await LocationService.getAreaCoordinates();
      if (areaCoords != null) {
        _userLat = areaCoords['lat'];
        _userLon = areaCoords['lon'];
      }
    }

    _isDetectingGps = false;
    notifyListeners();
  }

  // ── Manual override kawasan ───────────────────────────────────────
  // Dipanggil bila user tukar kawasan secara manual
  Future<void> setManualArea(String areaId, String areaName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_area_id', areaId);
    await prefs.setString('user_area_name', areaName);

    _userAreaId = areaId;
    _userArea = areaName;
    _gpsFromAuto = false; // Dah override manual

    // Update koordinat ke kawasan yang dipilih
    final area = KualaTerengganuAreas.getAreaById(areaId);
    if (area != null) {
      _userLat = area.latitude;
      _userLon = area.longitude;
    }

    notifyListeners();
  }

  // ── Apply filters & sort ──────────────────────────────────────────
  List<BantuanModel> applyFiltersAndSort(List<BantuanModel> rawList) {
    var list = List<BantuanModel>.from(rawList);

    if (_filterByArea && _userAreaId.isNotEmpty) {
      list = list.where((p) => p.areaId == _userAreaId).toList();
    }

    // Hard filter category — apply SAMA ADA dalam mod biasa atau Best Match.
    // Best Match guna criteria ni sebagai filter wajib, bukan sekadar ranking hint.
    if (_selectedCategories.isNotEmpty) {
      list = list.where((p) => _selectedCategories.contains(p.category)).toList();
    }

    // Best Match: hard filter tambahan untuk radius, type, availability
    if (_sortByRanking) {
      if (_bestMatchType != 'all') {
        list = list.where((p) => p.type == _bestMatchType).toList();
      }
      if (_bestMatchRequireAvailable) {
        list = list.where((p) => p.posterAvailability == 'available').toList();
      }
      if (_bestMatchRadiusKm > 0 && _userLat != null && _userLon != null) {
        list = list.where((p) {
          final dist = GeospatialService.getPostDistance(
            post: p,
            userLat: _userLat!,
            userLon: _userLon!,
          );
          return dist != null && dist <= _bestMatchRadiusKm;
        }).toList();
      }
    }

    if (_sortByNearest && _userLat != null && _userLon != null) {
      list = GeospatialService.nearestNeighbour(
        posts: list,
        userLat: _userLat!,
        userLon: _userLon!,
      );
    }

    if (_sortByRanking && _userLat != null && _userLon != null) {
      final ranked = GeospatialService.rankPosts(
        posts: list,
        userLat: _userLat!,
        userLon: _userLon!,
        preferredCategories: _selectedCategories,
        radiusKm: _bestMatchRadiusKm,
        filterType: _bestMatchType,
        requireAvailable: _bestMatchRequireAvailable,
      );
      list = ranked.map((r) => r.post).toList();
    }

    return list;
  }

  // ── Setters ───────────────────────────────────────────────────────
  void setSelectedType(String type) {
    if (_selectedType == type) return;
    _selectedType = type;
    notifyListeners();
  }

  void setFilterByArea(bool value) {
    _filterByArea = value;
    notifyListeners();
  }

  void setSortByNearest(bool value) {
    _sortByNearest = value;
    if (value) _sortByRanking = false;
    notifyListeners();
  }

  void setSortByRanking(bool value) {
    _sortByRanking = value;
    if (value) _sortByNearest = false;
    notifyListeners();
  }

  void setSelectedCategories(Set<String> categories) {
    _selectedCategories = Set.from(categories);
    notifyListeners();
  }

  void removeCategory(String id) {
    _selectedCategories.remove(id);
    notifyListeners();
  }

  void clearCategories() {
    _selectedCategories.clear();
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedCategories.clear();
    _filterByArea = false;
    notifyListeners();
  }

  void applyBestMatchCriteria({
    required Set<String> categories,
    required double radiusKm,
    required String type,
    required bool requireAvailable,
  }) {
    _selectedCategories = Set.from(categories);
    _bestMatchRadiusKm = radiusKm;
    _bestMatchType = type;
    _bestMatchRequireAvailable = requireAvailable;
    _sortByRanking = true;
    _sortByNearest = false;
    notifyListeners();
  }

  void resetBestMatchCriteria() {
    _bestMatchRadiusKm = 0;
    _bestMatchType = 'all';
    _bestMatchRequireAvailable = false;
    _selectedCategories.clear();
    _sortByRanking = false;
    notifyListeners();
  }

  Future<void> reloadArea() async {
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();
  }
  // ── Force refresh stream ──────────────────────────────────────────
  Future<void> refreshStream() async {
    await loadUserAreaAndLocation();
    notifyListeners();
  }
}