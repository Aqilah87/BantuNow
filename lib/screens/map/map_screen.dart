// lib/screens/map/map_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../utils/colors.dart';
import '../../models/bantuan_model.dart';
import '../bantuan/bantuan_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ✅ FIX 1: KT center sebagai default
  static const LatLng _ktCenter = LatLng(5.3296, 103.1370);
  LatLng _mapCenter = const LatLng(5.3296, 103.1370);

  LatLng? _userLocation;
  List<BantuanModel> _allPosts = [];
  List<BantuanModel> _filteredPosts = [];
  List<BantuanModel> _postResults = [];
  List<Map<String, dynamic>> _placeResults = [];

  String _selectedCategory = 'all';
  String _selectedType = 'all';
  bool _isLoadingPosts = true;
  bool _isLoadingPlaces = false;
  bool _isSearching = false;
  String _searchQuery = '';
  BantuanModel? _selectedPost;

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadPosts();

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase().trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _isSearching = query.isNotEmpty;
          _updatePostResults(query);
        });
        if (query.length >= 3) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_searchController.text.toLowerCase().trim() == query) {
              _searchPlaces(query);
            }
          });
        } else {
          setState(() => _placeResults = []);
        }
      }
    });
  }

  void _updatePostResults(String query) {
    if (query.isEmpty) {
      _postResults = [];
      return;
    }
    _postResults = _allPosts.where((post) {
      return post.title.toLowerCase().contains(query) ||
          post.area.toLowerCase().contains(query) ||
          post.postedBy.toLowerCase().contains(query) ||
          BantuanCategories.getCategoryName(post.category)
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isLoadingPlaces = true);
    try {
      final encodedQuery =
          Uri.encodeComponent('$query, Kuala Terengganu, Malaysia');
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=4&countrycodes=my');

      final response = await http.get(url, headers: {
        'User-Agent': 'BantuNow/1.0 (community assistance app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _placeResults = data
              .map((item) => {
                    'name': item['display_name']
                        .toString()
                        .split(',')
                        .first
                        .trim(),
                    'fullName': item['display_name'].toString(),
                    'lat': double.parse(item['lat'].toString()),
                    'lon': double.parse(item['lon'].toString()),
                  })
              .toList();
        });
      }
    } catch (_) {
      // network issue atau timeout — senyap
    } finally {
      setState(() => _isLoadingPlaces = false);
    }
  }

  // ✅ FIX 2: Update map center bila dapat user location
  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        final loc = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLocation = loc;
          _mapCenter = loc;
        });
        // Move map ke lokasi user
        _mapController.move(loc, 13);
      }
    } catch (_) {}
  }

  Future<void> _loadPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bantuan')
          .where('status', isEqualTo: 'open')
          .get();

      final posts = snapshot.docs
          .map((doc) =>
              BantuanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      setState(() {
        _allPosts = posts;
        _filteredPosts = posts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() => _isLoadingPosts = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredPosts = _allPosts.where((post) {
        final typeMatch =
            _selectedType == 'all' || post.type == _selectedType;
        final categoryMatch =
            _selectedCategory == 'all' || post.category == _selectedCategory;
        return typeMatch && categoryMatch;
      }).toList();
      _selectedPost = null;
    });
  }

  void _selectPost(BantuanModel post) {
    setState(() {
      _selectedPost = post;
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _postResults = [];
      _placeResults = [];
    });
    _searchFocus.unfocus();

    if (post.latitude != null && post.longitude != null) {
      _mapController.move(LatLng(post.latitude!, post.longitude!), 16);
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    final lat = place['lat'] as double;
    final lon = place['lon'] as double;

    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _postResults = [];
      _placeResults = [];
    });
    _searchFocus.unfocus();
    _mapController.move(LatLng(lat, lon), 16);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _postResults = [];
      _placeResults = [];
    });
    _searchFocus.unfocus();
  }

  String _getDistance(BantuanModel post) {
    if (_userLocation == null ||
        post.latitude == null ||
        post.longitude == null) return '';
    final distance = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      post.latitude!,
      post.longitude!,
    );
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filter Post',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setModalState(() {
                      _selectedType = 'all';
                      _selectedCategory = 'all';
                    }),
                    child: Text('Reset',
                        style: TextStyle(color: AppColors.primaryBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Jenis',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _filterChip('Semua', 'all', _selectedType,
                      AppColors.primaryBlue,
                      () => setModalState(() => _selectedType = 'all')),
                  const SizedBox(width: 8),
                  _filterChip('🙋 Request', 'request', _selectedType,
                      Colors.red,
                      () => setModalState(() => _selectedType = 'request')),
                  const SizedBox(width: 8),
                  _filterChip('🤲 Offer', 'offer', _selectedType,
                      Colors.blue,
                      () => setModalState(() => _selectedType = 'offer')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Kategori',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('Semua', 'all', _selectedCategory,
                      AppColors.primaryBlue,
                      () => setModalState(() => _selectedCategory = 'all')),
                  ...BantuanCategories.categories.map((c) => _filterChip(
                        '${c['icon']} ${(c['name'] as String).split(' / ')[0]}',
                        c['id'] as String,
                        _selectedCategory,
                        AppColors.primaryBlue,
                        () => setModalState(
                            () => _selectedCategory = c['id'] as String),
                      )),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyFilter();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guna Filter',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, String selected, Color color,
      VoidCallback onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : AppColors.textGrey)),
      ),
    );
  }

  bool get _hasSearchResults =>
      _postResults.isNotEmpty || _placeResults.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final postsWithCoords = _filteredPosts
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    // ✅ FIX 3: Kira count dulu — elak nested quotes dalam string interpolation
    final requestCount =
        postsWithCoords.where((p) => p.type == 'request').length;
    final offerCount =
        postsWithCoords.where((p) => p.type == 'offer').length;

    final markers = <Marker>[
      // User location marker
      if (_userLocation != null)
        Marker(
          point: _userLocation!,
          width: 50,
          height: 50,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 3)
              ],
            ),
          ),
        ),

      // Post markers
      ...postsWithCoords.map((post) {
        final isRequest = post.type == 'request';
        final color = isRequest ? Colors.red : Colors.blue;
        final isSelected = _selectedPost?.id == post.id;
        return Marker(
          point: LatLng(post.latitude!, post.longitude!),
          width: 44,
          height: 54,
          child: GestureDetector(
            onTap: () =>
                setState(() => _selectedPost = isSelected ? null : post),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 40 : 32,
                  height: isSelected ? 40 : 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 2)
                    ],
                  ),
                  child: Icon(
                    isRequest ? Icons.pan_tool : Icons.volunteer_activism,
                    color: Colors.white,
                    size: isSelected ? 22 : 16,
                  ),
                ),
                Container(
                    width: 3,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        );
      }),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // ✅ FIX 4: Guna _mapCenter yang boleh update
              initialCenter: _mapCenter,
              initialZoom: 13,
              onTap: (_, __) {
                setState(() => _selectedPost = null);
                if (_searchQuery.isEmpty) {
                  _searchFocus.unfocus();
                  setState(() => _isSearching = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bantunow.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Top UI ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search row
                  Row(
                    children: [
                      // Back button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8)
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Search bar
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8)
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onTap: () =>
                                setState(() => _isSearching = true),
                            decoration: InputDecoration(
                              hintText: 'Cari tempat atau bantuan...',
                              hintStyle: TextStyle(
                                  color: AppColors.textGrey, fontSize: 13),
                              prefixIcon: _isLoadingPlaces
                                  ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryBlue)),
                                    )
                                  : Icon(Icons.search,
                                      color: AppColors.primaryBlue,
                                      size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: AppColors.textGrey,
                                          size: 18),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Filter button
                      Container(
                        decoration: BoxDecoration(
                          color: (_selectedType != 'all' ||
                                  _selectedCategory != 'all')
                              ? AppColors.primaryBlue
                              : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8)
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune,
                              color: (_selectedType != 'all' ||
                                      _selectedCategory != 'all')
                                  ? Colors.white
                                  : AppColors.primaryBlue),
                          onPressed: _showFilter,
                        ),
                      ),
                    ],
                  ),

                  // Search results dropdown
                  if (_isSearching && _searchQuery.isNotEmpty)
                    Container(
                      margin:
                          const EdgeInsets.only(top: 8, left: 4, right: 4),
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: !_hasSearchResults && !_isLoadingPlaces
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      color: AppColors.textGrey, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Tiada hasil dijumpai',
                                      style: TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 13)),
                                ],
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                // Section: Nama Tempat
                                if (_placeResults.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 14,
                                            color: AppColors.primaryBlue),
                                        const SizedBox(width: 6),
                                        Text('Nama Tempat',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.primaryBlue)),
                                      ],
                                    ),
                                  ),
                                  ..._placeResults.map((place) => ListTile(
                                        dense: true,
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppColors.backgroundBlue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.place,
                                              color: AppColors.primaryBlue,
                                              size: 18),
                                        ),
                                        title: Text(
                                          place['name'],
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          place['fullName'],
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textGrey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Icon(Icons.north_west,
                                            size: 16,
                                            color: AppColors.primaryBlue),
                                        onTap: () => _selectPlace(place),
                                      )),
                                ],

                                if (_placeResults.isNotEmpty &&
                                    _postResults.isNotEmpty)
                                  const Divider(height: 1, indent: 16),

                                // Section: Post BantuNow
                                if (_postResults.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.people_alt_rounded,
                                            size: 14, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text('Post BantuNow',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange)),
                                      ],
                                    ),
                                  ),
                                  ...(_postResults.take(4).map((post) {
                                    final isRequest = post.type == 'request';
                                    final typeColor =
                                        isRequest ? Colors.red : Colors.blue;
                                    final distance = _getDistance(post);
                                    return ListTile(
                                      dense: true,
                                      leading: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: (isRequest
                                                  ? Colors.red
                                                  : Colors.blue)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isRequest
                                              ? Icons.pan_tool
                                              : Icons.volunteer_activism,
                                          color: isRequest
                                              ? Colors.red
                                              : Colors.blue,
                                          size: 16,
                                        ),
                                      ),
                                      title: Text(post.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark)),
                                      subtitle: Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1),
                                            decoration: BoxDecoration(
                                              color: typeColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isRequest
                                                  ? 'Request'
                                                  : 'Offer',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: typeColor,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(post.area,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .primaryBlue)),
                                          ),
                                        ],
                                      ),
                                      trailing: distance.isNotEmpty
                                          ? Text(distance,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.primaryBlue))
                                          : null,
                                      onTap: () => _selectPost(post),
                                    );
                                  })),
                                ],
                              ],
                            ),
                    ),

                  // Stats bar
                  if (!_isSearching || _searchQuery.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined,
                                size: 15, color: AppColors.primaryBlue),
                            const SizedBox(width: 6),
                            Text('${postsWithCoords.length} post',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark)),
                            const SizedBox(width: 10),
                            // ✅ FIX 3: Guna variable — elak nested quotes
                            _buildMiniChip('$requestCount', Colors.red),
                            const SizedBox(width: 4),
                            _buildMiniChip('$offerCount', Colors.blue),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Legend ───────────────────────────────────────────────────────
          if (!_isSearching)
            Positioned(
              left: 12,
              bottom: _selectedPost != null ? 230 : 100,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 6)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(Colors.red, '🙋 Request'),
                    const SizedBox(height: 6),
                    _buildLegendItem(Colors.blue, '🤲 Offer'),
                    const SizedBox(height: 6),
                    _buildLegendItem(Colors.green, '📍 Saya'),
                  ],
                ),
              ),
            ),

          // ── My location button ────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: _selectedPost != null ? 230 : 100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15), blurRadius: 8)
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.my_location, color: AppColors.primaryBlue),
                onPressed: () {
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 15);
                  } else {
                    _mapController.move(_ktCenter, 13);
                  }
                },
              ),
            ),
          ),

          // ── Selected post card ────────────────────────────────────────────
          if (_selectedPost != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_selectedPost!.type == 'request'
                                    ? Colors.red
                                    : Colors.blue)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedPost!.type == 'request'
                                ? '🙋 Request'
                                : '🤲 Offer',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedPost!.type == 'request'
                                    ? Colors.red
                                    : Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${BantuanCategories.getCategoryIcon(_selectedPost!.category)} ${BantuanCategories.getCategoryName(_selectedPost!.category).split(' / ')[0]}',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryBlue),
                          ),
                        ),
                        const Spacer(),
                        if (_getDistance(_selectedPost!).isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.near_me,
                                  size: 14, color: AppColors.primaryBlue),
                              const SizedBox(width: 4),
                              Text(_getDistance(_selectedPost!),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryBlue)),
                            ],
                          ),
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: AppColors.textGrey),
                          onPressed: () =>
                              setState(() => _selectedPost = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_selectedPost!.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(_selectedPost!.postedBy,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textGrey)),
                        const Spacer(),
                        Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 2),
                        Text(_selectedPost!.area,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryBlue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BantuanDetailScreen(
                                bantuan: _selectedPost!,
                                onLoginRequired: (_) {},
                                isLoggedIn: _isLoggedIn,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Lihat Details',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading overlay ───────────────────────────────────────────────
          if (_isLoadingPosts)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Memuatkan post...',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(count,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}