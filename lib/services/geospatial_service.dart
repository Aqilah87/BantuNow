// lib/services/geospatial_service.dart

import 'dart:math';
import '../models/bantuan_model.dart';

class GeospatialService {
  // Radius bumi dalam kilometer (digunakan untuk kira jarak geografi)
  static const double _earthRadiusKm = 6371.0;

  // ────────────────────────────────────────────────────────────────
  // HAVERSINE FORMULA
  // Digunakan untuk mengira jarak antara dua koordinat (latitude, longitude)
  // berdasarkan bentuk sfera bumi.
  // Output: jarak dalam kilometer
  // ────────────────────────────────────────────────────────────────
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Perbezaan latitude & longitude dalam radian
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    // Formula Haversine
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Jarak akhir = radius bumi × sudut
    return _earthRadiusKm * c;
  }

  // Convert degree ke radian
  static double _toRad(double degree) => degree * (pi / 180);

  // ────────────────────────────────────────────────────────────────
  // NEAREST NEIGHBOUR
  // Susun post berdasarkan jarak paling dekat dengan user
  // Complexity: O(n log n) sebab sorting
  // ────────────────────────────────────────────────────────────────
  static List<BantuanModel> nearestNeighbour({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
  }) {
    // Map setiap post kepada jarak
    final withDistance = posts.map((post) {
      final distance = (post.latitude != null && post.longitude != null)
          ? haversineDistance(
              lat1: userLat,
              lon1: userLon,
              lat2: post.latitude!,
              lon2: post.longitude!,
            )
          : double.infinity; // jika tiada lokasi → letak jauh

      return _PostWithDistance(post: post, distanceKm: distance);
    }).toList();

    // Sort ikut jarak (ascending → paling dekat dulu)
    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // Return hanya post
    return withDistance.map((e) => e.post).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // COMPOSITE SCORING & RANKING ALGORITHM
  //
  // Digunakan untuk tentukan "best match post"
  // berdasarkan beberapa faktor:
  //
  //   Jarak        → 40% (lebih dekat = lebih tinggi score)
  //   Masa         → 30% (lebih baru = lebih tinggi score)
  //   Urgency      → 20% (request > offer)
  //   Kategori     → 10% (ikut preference user)
  //
  // ────────────────────────────────────────────────────────────────
  static List<RankedPost> rankPosts({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
    Set<String> preferredCategories = const {},
    double radiusKm = 0,
    bool requireAvailable = false,
    String filterType = 'all',
  }) {
    if (posts.isEmpty) return [];

    // ── STEP 0: FILTER DATA ───────────────────────────────
    final filtered = posts.where((post) {

      // Filter jenis post (request / offer)
      if (filterType != 'all' && post.type != filterType) return false;

      // Filter availability (hanya user available)
      if (requireAvailable) {
        final avail = post.posterAvailability ?? 'available';
        if (avail != 'available') return false;
      }

      // Filter radius (buang post luar kawasan)
      if (radiusKm > 0) {
        if (post.latitude == null || post.longitude == null) return false;

        final dist = haversineDistance(
          lat1: userLat,
          lon1: userLon,
          lat2: post.latitude!,
          lon2: post.longitude!,
        );

        if (dist > radiusKm) return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) return [];

    // ── STEP 1: EXTRACT RAW DATA ─────────────────────────
    final rawData = filtered.map((post) {

      // kira jarak
      final distance = (post.latitude != null && post.longitude != null)
          ? haversineDistance(
              lat1: userLat,
              lon1: userLon,
              lat2: post.latitude!,
              lon2: post.longitude!,
            )
          : double.infinity;

      // kira umur post dalam jam
      final ageHours =
          DateTime.now().difference(post.createdAt).inHours.toDouble();

      return _RawPostData(
        post: post,
        distanceKm: distance,
        ageHours: ageHours,
      );
    }).toList();

    // ── STEP 2: NORMALIZATION (0 - 1) ────────────────────
    // untuk pastikan semua faktor dalam skala sama

    final validDistances = rawData
        .where((d) => d.distanceKm != double.infinity)
        .map((d) => d.distanceKm)
        .toList();

    final maxDistance =
        validDistances.isEmpty ? 1.0 : validDistances.reduce(max);

    final maxAge =
        rawData.map((d) => d.ageHours).reduce(max).clamp(1.0, double.infinity);

    // ── STEP 3: CALCULATE SCORE ─────────────────────────
    final ranked = rawData.map((data) {

      // Distance score (lebih dekat → score tinggi)
      final distanceScore = data.distanceKm == double.infinity
          ? 0.0
          : 1.0 - (data.distanceKm / maxDistance).clamp(0.0, 1.0);

      // Recency score (lebih baru → score tinggi)
      final recencyScore =
          1.0 - (data.ageHours / maxAge).clamp(0.0, 1.0);

      // Urgency score
      final urgencyScore = filterType != 'all'
          ? 0.8
          : (data.post.type == 'request' ? 1.0 : 0.6);

      // Category score (match preference user)
      final categoryScore = preferredCategories.isEmpty
          ? 0.5
          : preferredCategories.contains(data.post.category)
              ? 1.0
              : 0.2;

      // FINAL SCORE (weighted sum)
      final compositeScore = (distanceScore * 0.4) +
          (recencyScore * 0.3) +
          (urgencyScore * 0.2) +
          (categoryScore * 0.1);

      return RankedPost(
        post: data.post,
        compositeScore: compositeScore,
        distanceKm:
            data.distanceKm == double.infinity ? null : data.distanceKm,
        distanceScore: distanceScore,
        recencyScore: recencyScore,
        urgencyScore: urgencyScore,
        categoryScore: categoryScore,
      );
    }).toList();

    // ── STEP 4: SORT RESULT ─────────────────────────────
    // Susun dari score tertinggi ke terendah
    ranked.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));

    return ranked;
  }

  // ────────────────────────────────────────────────────────────────
  // FILTER BY RADIUS
  // Return post dalam jarak tertentu sahaja
  // ────────────────────────────────────────────────────────────────
  static List<BantuanModel> filterByRadius({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
    required double radiusKm,
  }) {
    return posts.where((post) {
      if (post.latitude == null || post.longitude == null) return false;

      final distance = haversineDistance(
        lat1: userLat,
        lon1: userLon,
        lat2: post.latitude!,
        lon2: post.longitude!,
      );

      return distance <= radiusKm;
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // HELPER FUNCTIONS
  // ────────────────────────────────────────────────────────────────

  // Convert jarak ke format display (UI)
  static String getDistanceLabel(double km) {
    if (km == double.infinity) return '';
    if (km < 1.0) return '${(km * 1000).toStringAsFixed(0)}m';
    return '${km.toStringAsFixed(1)}km';
  }

  // Kira jarak satu post dengan user
  static double? getPostDistance({
    required BantuanModel post,
    required double userLat,
    required double userLon,
  }) {
    if (post.latitude == null || post.longitude == null) return null;

    return haversineDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: post.latitude!,
      lon2: post.longitude!,
    );
  }
}

// ────────────────────────────────────────────────────────────────
// DATA CLASSES
// ────────────────────────────────────────────────────────────────

// Simpan hasil ranking + semua score detail
class RankedPost {
  final BantuanModel post;
  final double compositeScore;
  final double? distanceKm;
  final double distanceScore;
  final double recencyScore;
  final double urgencyScore;
  final double categoryScore;

  const RankedPost({
    required this.post,
    required this.compositeScore,
    required this.distanceKm,
    required this.distanceScore,
    required this.recencyScore,
    required this.urgencyScore,
    required this.categoryScore,
  });
}

// Simpan post + jarak sahaja
class _PostWithDistance {
  final BantuanModel post;
  final double distanceKm;

  const _PostWithDistance({
    required this.post,
    required this.distanceKm,
  });
}

// Simpan data mentah sebelum scoring
class _RawPostData {
  final BantuanModel post;
  final double distanceKm;
  final double ageHours;

  const _RawPostData({
    required this.post,
    required this.distanceKm,
    required this.ageHours,
  });
}