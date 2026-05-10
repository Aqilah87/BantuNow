// lib/screens/map/map_picker_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../utils/colors.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final String areaName;

  const MapPickerScreen({
    Key? key,
    required this.initialLat,
    required this.initialLon,
    required this.areaName,
  }) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapController _mapController;
  LatLng? _pickedLocation;
  String _addressText = '';
  bool _isLoadingAddress = false;
  bool _isLoadingGps = false;

  // ── Search ─────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pickedLocation = LatLng(widget.initialLat, widget.initialLon);
    _reverseGeocode(_pickedLocation!);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search — debounce 600ms ─────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchPlaces(query.trim());
    });
  }

  // ── Nominatim forward geocode ───────────────────────────────────────
  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=6'
        '&countrycodes=my'
        '&viewbox=102.5,4.5,103.8,6.0'
        '&bounded=0',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'BantuNow/1.0 (community assistance app)',
        'Accept-Language': 'ms,en',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) {
            final displayName = item['display_name'] as String;
            final parts = displayName.split(',');
            return {
              'display_name': displayName,
              'lat': double.parse(item['lat'] as String),
              'lon': double.parse(item['lon'] as String),
              'type': item['type'] ?? '',
              'class': item['class'] ?? '',
              'short_name': parts.first.trim(),
              'sub_name': parts.skip(1).take(3).join(',').trim(),
            };
          }).toList();
          _showResults = true;
        });
      }
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// User pilih result — pindah map ke sana
  void _selectSearchResult(Map<String, dynamic> result) {
    final latlng = LatLng(result['lat'] as double, result['lon'] as double);
    setState(() {
      _pickedLocation = latlng;
      _searchResults = [];
      _showResults = false;
      _searchController.text = result['short_name'] as String;
    });
    _searchFocus.unfocus();
    _mapController.move(latlng, 17);
    _reverseGeocode(latlng);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
    _searchFocus.unfocus();
  }

  // ── Reverse geocode ─────────────────────────────────────────────────
  Future<void> _reverseGeocode(LatLng latlng) async {
    setState(() {
      _isLoadingAddress = true;
      _addressText = '';
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${latlng.latitude}&lon=${latlng.longitude}'
        '&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BantuNow/1.0 (community assistance app)',
        'Accept-Language': 'ms,en',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          final road = address['road'] ??
              address['pedestrian'] ??
              address['path'] ??
              address['footway'];
          final neighbourhood = address['neighbourhood'] ??
              address['suburb'] ??
              address['village'];
          final city =
              address['city'] ?? address['town'] ?? address['county'];
          final state = address['state'];
          if (road != null) parts.add(road);
          if (neighbourhood != null) parts.add(neighbourhood);
          if (city != null) parts.add(city);
          if (state != null) parts.add(state);
          setState(() {
            _addressText = parts.isNotEmpty
                ? parts.join(', ')
                : data['display_name'] ?? '';
          });
        } else {
          setState(() => _addressText = data['display_name'] ?? '');
        }
      }
    } catch (_) {
      setState(() => _addressText = '');
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  // ── GPS ─────────────────────────────────────────────────────────────
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('GPS dimatikan. Sila hidupkan GPS.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Permission GPS ditolak.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Permission GPS dihalang. Pergi Setting untuk buka.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLocation = latlng);
      _mapController.move(latlng, 17);
      await _reverseGeocode(latlng);
    } catch (e) {
      _showSnack('Gagal detect lokasi: $e');
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    if (_showResults) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      _searchFocus.unfocus();
      return;
    }
    setState(() => _pickedLocation = latlng);
    _reverseGeocode(latlng);
  }

  void _confirmLocation() {
    if (_pickedLocation == null) return;
    Navigator.pop(context, {
      'lat': _pickedLocation!.latitude,
      'lon': _pickedLocation!.longitude,
      'address': _addressText,
    });
  }

  // ── Icon ikut jenis tempat ──────────────────────────────────────────
  IconData _placeIcon(String type, String placeClass) {
    switch (placeClass) {
      case 'highway':
        return Icons.turn_right;
      case 'amenity':
        switch (type) {
          case 'school':
          case 'university':
            return Icons.school;
          case 'hospital':
          case 'clinic':
            return Icons.local_hospital;
          case 'mosque':
            return Icons.mosque;
          case 'restaurant':
          case 'cafe':
            return Icons.restaurant;
          default:
            return Icons.place;
        }
      case 'shop':
        return Icons.shopping_bag;
      case 'leisure':
        return Icons.park;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap luar search = tutup keyboard & results
      onTap: () {
        _searchFocus.unfocus();
        if (_showResults) {
          setState(() {
            _showResults = false;
            _searchResults = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: AppColors.primaryBlue,
          elevation: 0,
          title: const Text(
            'Pin Lokasi',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _pickedLocation == null ? null : _confirmLocation,
              child: const Text(
                'Guna',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [

            // ── Map ───────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    LatLng(widget.initialLat, widget.initialLon),
                initialZoom: 15,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bantunow.app',
                ),
                if (_pickedLocation != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: const _PinWidget(),
                    ),
                  ]),
              ],
            ),

            // ── Search bar + dropdown ─────────────────────────────────
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                children: [

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari taman, lorong, jalan...',
                        hintStyle: TextStyle(
                            fontSize: 14, color: AppColors.textGrey),
                        prefixIcon: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              )
                            : Icon(Icons.search,
                                color: AppColors.primaryBlue, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: AppColors.textGrey, size: 20),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  // ── Search results dropdown ───────────────────────
                  if (_showResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header hasil
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              color: AppColors.backgroundBlue,
                              child: Text(
                                '${_searchResults.length} lokasi dijumpai',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),

                            // Senarai hasil
                            ...List.generate(_searchResults.length, (i) {
                              final r = _searchResults[i];
                              final isLast = i == _searchResults.length - 1;
                              return Column(children: [
                                InkWell(
                                  onTap: () => _selectSearchResult(r),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(children: [
                                      // Icon jenis tempat
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _placeIcon(r['type'] as String,
                                              r['class'] as String),
                                          size: 18,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Nama tempat
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r['short_name'] as String,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color:
                                                      AppColors.textDark),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            if ((r['sub_name'] as String)
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                r['sub_name'] as String,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textGrey),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          size: 18,
                                          color: AppColors.textGrey),
                                    ]),
                                  ),
                                ),
                                if (!isLast)
                                  Divider(
                                      height: 1,
                                      indent: 64,
                                      color: Colors.grey.shade100),
                              ]);
                            }),
                          ],
                        ),
                      ),
                    ),

                  // ── Tiada hasil ───────────────────────────────────
                  if (_showResults &&
                      _searchResults.isEmpty &&
                      !_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(children: [
                        Icon(Icons.search_off,
                            size: 18, color: AppColors.textGrey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tiada lokasi dijumpai. Cuba kata kunci lain.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textGrey),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),

            // ── Instruction hint (hidden bila results terbuka) ────────
            if (!_showResults)
              Positioned(
                top: 78,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    Icon(Icons.touch_app,
                        size: 15, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cari lokasi di atas atau tekan peta untuk letak pin',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textDark),
                      ),
                    ),
                  ]),
                ),
              ),

            // ── GPS button ────────────────────────────────────────────
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'gps_btn',
                onPressed: _isLoadingGps ? null : _goToCurrentLocation,
                backgroundColor: Colors.white,
                elevation: 4,
                child: _isLoadingGps
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : Icon(Icons.my_location,
                        color: AppColors.primaryBlue, size: 20),
              ),
            ),

            // ── Address + Confirm panel bawah ─────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),

                    // Koordinat
                    if (_pickedLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.gps_fixed,
                              size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            '${_pickedLocation!.latitude.toStringAsFixed(6)}, '
                            '${_pickedLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                fontFamily: 'monospace'),
                          ),
                        ]),
                      ),

                    // Alamat
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on,
                            size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isLoadingAddress
                              ? Row(children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Mencari alamat...',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textGrey)),
                                ])
                              : Text(
                                  _addressText.isNotEmpty
                                      ? _addressText
                                      : 'Tekan peta untuk pilih lokasi',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _addressText.isNotEmpty
                                          ? AppColors.textDark
                                          : AppColors.textGrey,
                                      height: 1.4),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _pickedLocation == null
                            ? null
                            : _confirmLocation,
                        icon: const Icon(Icons.check,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Guna Lokasi Ini',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pin widget ──────────────────────────────────────────────────────────────
class _PinWidget extends StatelessWidget {
  const _PinWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: AppColors.primaryBlue),
        ),
      ],
    );
  }
}

// ── Pin tail painter ────────────────────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}