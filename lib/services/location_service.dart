// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

class LocationService {

  // ── GET CURRENT GPS ───────────────────────────────────────────────
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  // ── GET AREA COORDINATES (fallback) ──────────────────────────────
  static Future<Map<String, double>?> getAreaCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final areaId = prefs.getString('user_area_id');
    if (areaId == null) return null;

    final area = KualaTerengganuAreas.getAreaById(areaId);
    if (area == null) return null;

    return {'lat': area.latitude, 'lon': area.longitude};
  }

  // ── GET BEST LOCATION ─────────────────────────────────────────────
  // Priority: GPS → Area fallback
  static Future<Map<String, double>?> getBestLocation() async {
    final gps = await getCurrentLocation();
    if (gps != null) {
      return {'lat': gps.latitude, 'lon': gps.longitude};
    }
    return await getAreaCoordinates();
  }

  // ── AUTO DETECT AREA FROM GPS ─────────────────────────────────────
  // Detect GPS → cari kawasan terdekat → return LocationArea
  // Digunakan untuk auto-set kawasan user tanpa perlu pilih manual
  static Future<LocationArea?> detectNearestArea() async {
    final gps = await getCurrentLocation();
    if (gps == null) return null;

    return getNearestArea(gps.latitude, gps.longitude);
  }

  // ── GET NEAREST AREA (dari koordinat) ────────────────────────────
  // Cari kawasan paling dekat berdasarkan koordinat lat/lon
  static LocationArea? getNearestArea(double lat, double lon) {
    if (KualaTerengganuAreas.areas.isEmpty) return null;

    LocationArea? nearest;
    double minDistance = double.infinity;

    for (final area in KualaTerengganuAreas.areas) {
      final distance = Geolocator.distanceBetween(
        lat, lon,
        area.latitude, area.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = area;
      }
    }

    return nearest;
  }

  // ── CHECK GPS PERMISSION STATUS ───────────────────────────────────
  static Future<LocationPermissionStatus> checkPermissionStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }
    return LocationPermissionStatus.granted;
  }
}

// Status GPS permission untuk display UI yang sesuai
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}