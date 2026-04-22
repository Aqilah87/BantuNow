// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

class LocationService {
  /// Dapatkan GPS location user (realtime)
  /// Return null kalau permission denied atau GPS off
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

  /// Dapatkan koordinat dari area yang user pilih (fallback)
  static Future<Map<String, double>?> getAreaCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final areaId = prefs.getString('user_area_id');
    if (areaId == null) return null;

    final area = KualaTerengganuAreas.getAreaById(areaId);
    if (area == null) return null;

    return {'lat': area.latitude, 'lon': area.longitude};
  }

  /// ── Main function ──────────────────────────────────────────────
  /// Cuba GPS dulu, fallback ke area coordinates
  static Future<Map<String, double>?> getBestLocation() async {
    // Cuba GPS realtime dulu
    final gps = await getCurrentLocation();
    if (gps != null) {
      return {'lat': gps.latitude, 'lon': gps.longitude};
    }

    // Fallback — guna koordinat kawasan yang user pilih
    return await getAreaCoordinates();
  }
}