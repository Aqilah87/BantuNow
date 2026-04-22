// lib/services/geospatial_service.dart

import 'dart:math';
import '../models/bantuan_model.dart';

class GeospatialService {
  static const double _earthRadiusKm = 6371.0;

  /// ── Haversine Formula ──────────────────────────────────────────
  /// Kira jarak sebenar (km) antara 2 titik koordinat di permukaan bumi
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRad(double degree) => degree * (pi / 180);

  /// ── Nearest Neighbour Algorithm ────────────────────────────────
  /// Sort senarai post bantuan dari yang paling dekat ke paling jauh
  /// berdasarkan koordinat user
  static List<BantuanModel> nearestNeighbour({
    required List<BantuanModel> posts,
    required double userLat,
    required double userLon,
  }) {
    // Attach jarak ke setiap post, skip post yang tiada koordinat
    final withDistance = posts.map((post) {
      final distance = (post.latitude != null && post.longitude != null)
          ? haversineDistance(
              lat1: userLat,
              lon1: userLon,
              lat2: post.latitude!,
              lon2: post.longitude!,
            )
          : double.infinity; // post tanpa koordinat letak kat hujung
      return _PostWithDistance(post: post, distanceKm: distance);
    }).toList();

    // Sort ascending — paling dekat dulu
    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return withDistance.map((e) => e.post).toList();
  }

  /// ── Filter by radius ───────────────────────────────────────────
  /// Return hanya post dalam radius tertentu (km) dari user
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

  /// ── Get distance string ────────────────────────────────────────
  /// Return formatted string jarak untuk display dalam UI
  static String getDistanceLabel(double km) {
    if (km == double.infinity) return '';
    if (km < 1.0) return '${(km * 1000).toStringAsFixed(0)}m';
    return '${km.toStringAsFixed(1)}km';
  }

  /// ── Get distance untuk satu post ──────────────────────────────
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

/// Internal helper class — jangan export
class _PostWithDistance {
  final BantuanModel post;
  final double distanceKm;
  const _PostWithDistance({required this.post, required this.distanceKm});
}