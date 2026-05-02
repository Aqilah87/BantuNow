// lib/providers/bantuan_provider.dart
//
// Provider untuk manage state home screen:
// - Filter (type, category, area)
// - Sort (nearest, best match)
// - User location (lat/lon)
// - Stream dari BantuanService
//
// TIDAK mengubah logic dalam bantuan_service.dart atau geospatial_service.dart
// Hanya memindahkan state dari HomeScreen ke sini

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bantuan_model.dart';
import '../services/bantuan_service.dart';
import '../services/geospatial_service.dart';
import '../services/location_service.dart';

class BantuanProvider extends ChangeNotifier {
  final BantuanService _bantuanService = BantuanService();

  // ── User location & area ─────────────────────────────────────────────────────
  String _userArea = '';
  String _userAreaId = '';
  double? _userLat;
  double? _userLon;

  String get userArea => _userArea;
  String get userAreaId => _userAreaId;
  double? get userLat => _userLat;
  double? get userLon => _userLon;

  // ── Filter state ─────────────────────────────────────────────────────────────
  String _selectedType = 'all';           // 'all' | 'request' | 'offer'
  Set<String> _selectedCategories = {};   // kosong = semua kategori
  bool _filterByArea = false;             // filter ikut kawasan user

  String get selectedType => _selectedType;
  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
  bool get filterByArea => _filterByArea;

  // ── Sort state ───────────────────────────────────────────────────────────────
  bool _sortByNearest = false;   // sort ikut jarak terdekat
  bool _sortByRanking = false;   // sort ikut composite score (best match)

  bool get sortByNearest => _sortByNearest;
  bool get sortByRanking => _sortByRanking;

  // ── Stream dari Firestore ────────────────────────────────────────────────────
  // Sama seperti yang digunakan dalam HomeScreen sebelum ini
  Stream<List<BantuanModel>> get bantuanStream => _bantuanService.getBantuanStream(
    type: _selectedType == 'all' ? null : _selectedType,
  );

  // ── Init — load area dan location ────────────────────────────────────────────
  Future<void> loadUserAreaAndLocation() async {
    // Load area dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();

    // Load GPS location — sama seperti _loadUserArea() dalam HomeScreen
    final location = await LocationService.getBestLocation();
    if (location != null) {
      _userLat = location['lat'];
      _userLon = location['lon'];
      notifyListeners();
    }
  }

  // ── Apply filter & sort pada list ────────────────────────────────────────────
  // Logic sama seperti dalam _buildBantuanList() HomeScreen — tidak diubah
  List<BantuanModel> applyFiltersAndSort(List<BantuanModel> rawList) {
    var list = List<BantuanModel>.from(rawList);

    // Filter ikut kawasan
    if (_filterByArea && _userAreaId.isNotEmpty) {
      list = list.where((p) => p.areaId == _userAreaId).toList();
    }

    // Filter ikut kategori
    if (_selectedCategories.isNotEmpty) {
      list = list.where((p) => _selectedCategories.contains(p.category)).toList();
    }

    // Sort ikut jarak terdekat — guna GeospatialService.nearestNeighbour()
    if (_sortByNearest && _userLat != null && _userLon != null) {
      list = GeospatialService.nearestNeighbour(
        posts: list,
        userLat: _userLat!,
        userLon: _userLon!,
      );
    }

    // Sort ikut best match — guna GeospatialService.rankPosts()
    if (_sortByRanking && _userLat != null && _userLon != null) {
      final ranked = GeospatialService.rankPosts(
        posts: list,
        userLat: _userLat!,
        userLon: _userLon!,
        preferredCategories: _selectedCategories,
      );
      list = ranked.map((r) => r.post).toList();
    }

    return list;
  }

  // ── Setters — setiap setter call notifyListeners() ───────────────────────────

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
    if (value) _sortByRanking = false; // mutual exclusive
    notifyListeners();
  }

  void setSortByRanking(bool value) {
    _sortByRanking = value;
    if (value) _sortByNearest = false; // mutual exclusive
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

  // ── Reload area (dipanggil selepas tukar kawasan) ────────────────────────────
  Future<void> reloadArea() async {
    final prefs = await SharedPreferences.getInstance();
    _userArea = prefs.getString('user_area_name') ?? '';
    _userAreaId = prefs.getString('user_area_id') ?? '';
    notifyListeners();
  }
}