// lib/services/geospatial_service.dart

import 'dart:math';
import '../models/bantuan_model.dart';

class GeospatialService {
  static const double _earthRadiusKm = 6371.0;

  // ─── Haversine Formula ────────────────────────────────────────────
  // Time complexity: O(1) — operasi matematik tetap, tak bergantung
  // pada saiz input
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRad(double degree) => degree * (pi / 180);

  // ─── Nearest Neighbour ────────────────────────────────────────────
  // Time complexity: O(n log n) — n untuk kira jarak, log n untuk sort
  // Scalability: Sesuai untuk sehingga ~10,000 posts
  static List<BantuanModel> nearestNeighbour({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
  }) {
    final withDistance = posts.map((post) {
      final distance = (post.latitude != null && post.longitude != null)
          ? haversineDistance(
              lat1: userLat,
              lon1: userLon,
              lat2: post.latitude!,
              lon2: post.longitude!,
            )
          : double.infinity;
      return _PostWithDistance(post: post, distanceKm: distance);
    }).toList();

    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return withDistance.map((e) => e.post).toList();
  }

  // ─── Composite Scoring & Ranking Algorithm ────────────────────────
  // Gabungkan 4 faktor dengan weightage berbeza:
  //
  //   Faktor            Weight    Justifikasi
  //   ─────────────────────────────────────────
  //   Jarak             40%       Post dekat lebih relevan
  //   Masa (recency)    30%       Post baru lebih relevan
  //   Urgency (type)    20%       Request lebih urgent dari offer
  //   Kategori          10%       Kategori kegemaran user
  //
  // Time complexity : O(n log n) — O(n) score + O(n log n) sort
  // Scalability     : Sesuai untuk ~10,000 posts (client-side)
  //                   Untuk >10,000, perlu server-side pagination
  static List<RankedPost> rankPosts({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
    Set<String> preferredCategories = const {},
  }) {
    if (posts.isEmpty) return [];

    // ── Step 1: Kira raw values untuk semua posts ──
    final rawData = posts.map((post) {
      final distance = (post.latitude != null && post.longitude != null)
          ? haversineDistance(
              lat1: userLat, lon1: userLon,
              lat2: post.latitude!, lon2: post.longitude!)
          : double.infinity;

      final ageHours =
          DateTime.now().difference(post.createdAt).inHours.toDouble();

      return _RawPostData(
        post: post,
        distanceKm: distance,
        ageHours: ageHours,
      );
    }).toList();

    // ── Step 2: Normalize setiap faktor ke 0.0–1.0 ──
    // Normalization penting supaya unit berbeza (km vs jam) boleh
    // digabungkan secara adil dalam composite score

    // Jarak — ambil max distance yang bukan infinity
    final validDistances = rawData
        .where((d) => d.distanceKm != double.infinity)
        .map((d) => d.distanceKm)
        .toList();
    final maxDistance =
        validDistances.isEmpty ? 1.0 : validDistances.reduce(max);

    // Masa — ambil max age
    final maxAge =
        rawData.map((d) => d.ageHours).reduce(max).clamp(1.0, double.infinity);

    // ── Step 3: Kira composite score setiap post ──
    final ranked = rawData.map((data) {
      // Jarak score: makin dekat makin tinggi score (inverse)
      // Score = 1.0 kalau jarak = 0, score = 0.0 kalau jarak = max
      final distanceScore = data.distanceKm == double.infinity
          ? 0.0
          : 1.0 - (data.distanceKm / maxDistance).clamp(0.0, 1.0);

      // Recency score: makin baru makin tinggi score (inverse age)
      final recencyScore =
          1.0 - (data.ageHours / maxAge).clamp(0.0, 1.0);

      // Urgency score: request = 1.0, offer = 0.6
      // Request dapat score lebih tinggi sebab ia keperluan mendesak
      final urgencyScore = data.post.type == 'request' ? 1.0 : 0.6;

      // Category score: kalau kategori dalam preference user = 1.0
      // Kalau tiada preference, semua dapat score neutral 0.5
      final categoryScore = preferredCategories.isEmpty
          ? 0.5
          : preferredCategories.contains(data.post.category)
              ? 1.0
              : 0.2;

      // ── Composite score dengan weightage ──
      // Total weight = 0.4 + 0.3 + 0.2 + 0.1 = 1.0
      final compositeScore = (distanceScore * 0.4) +
          (recencyScore * 0.3) +
          (urgencyScore * 0.2) +
          (categoryScore * 0.1);

      return RankedPost(
        post: data.post,
        compositeScore: compositeScore,
        distanceKm: data.distanceKm == double.infinity
            ? null
            : data.distanceKm,
        distanceScore: distanceScore,
        recencyScore: recencyScore,
        urgencyScore: urgencyScore,
        categoryScore: categoryScore,
      );
    }).toList();

    // ── Step 4: Sort descending — score tertinggi dulu ──
    ranked.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));

    return ranked;
  }

  // ─── Filter by radius ─────────────────────────────────────────────
  // Time complexity: O(n) — scan sekali sahaja
  static List<BantuanModel> filterByRadius({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
    required double radiusKm,
  }) {
    return posts.where((post) {
      if (post.latitude == null || post.longitude == null) return false;
      final distance = haversineDistance(
        lat1: userLat, lon1: userLon,
        lat2: post.latitude!, lon2: post.longitude!,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  static String getDistanceLabel(double km) {
    if (km == double.infinity) return '';
    if (km < 1.0) return '${(km * 1000).toStringAsFixed(0)}m';
    return '${km.toStringAsFixed(1)}km';
  }

  static double? getPostDistance({
    required BantuanModel post,
    required double userLat,
    required double userLon,
  }) {
    if (post.latitude == null || post.longitude == null) return null;
    return haversineDistance(
      lat1: userLat, lon1: userLon,
      lat2: post.latitude!, lon2: post.longitude!,
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────

/// Hasil ranking — satu post dengan semua score breakdown
class RankedPost {
  final BantuanModel post;
  final double compositeScore; // 0.0 – 1.0, makin tinggi makin relevan
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

class _PostWithDistance {
  final BantuanModel post;
  final double distanceKm;
  const _PostWithDistance({required this.post, required this.distanceKm});
}

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