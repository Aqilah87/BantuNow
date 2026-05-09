// lib/screens/location/select_location_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../providers/bantuan_provider.dart';
import '../../models/location_model.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_button.dart';
import '../main_screen.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({Key? key}) : super(key: key);

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  String? _selectedAreaId;
  List<LocationArea> _filteredAreas = KualaTerengganuAreas.areas;
  bool _isDetectingGps = false;
  String? _gpsDetectedAreaName;

  void _filterAreas(String query) {
    setState(() {
      _filteredAreas = query.isEmpty
          ? KualaTerengganuAreas.areas
          : KualaTerengganuAreas.areas
              .where((area) =>
                  area.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  // Auto detect GPS → cari kawasan terdekat → pilih terus
  Future<void> _detectGpsLocation(bool isMalay) async {
    setState(() {
      _isDetectingGps = true;
      _gpsDetectedAreaName = null;
    });

    final status = await LocationService.checkPermissionStatus();

    if (status == LocationPermissionStatus.deniedForever) {
      if (!mounted) return;
      setState(() => _isDetectingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Permission GPS dihalang. Sila buka Setting → App → Permission'
            : 'GPS permission blocked. Please go to Settings → App → Permission'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    if (status == LocationPermissionStatus.serviceDisabled) {
      if (!mounted) return;
      setState(() => _isDetectingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'GPS dimatikan. Sila hidupkan GPS anda'
            : 'GPS is off. Please enable GPS'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final nearest = await LocationService.detectNearestArea();

    if (!mounted) return;

    if (nearest == null) {
      setState(() => _isDetectingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Tidak dapat detect lokasi. Cuba pilih manual'
            : 'Cannot detect location. Please select manually'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() {
      _isDetectingGps = false;
      _selectedAreaId = nearest.id;
      _gpsDetectedAreaName = nearest.name;
    });

    // Scroll list ke kawasan yang dipilih
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.gps_fixed, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          '${isMalay ? 'Lokasi dijumpai' : 'Location found'}: ${nearest.name}',
        ),
      ]),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _saveLocationAndContinue(bool isMalay) async {
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            isMalay ? 'Sila pilih kawasan anda' : 'Please select your area'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final areaName = KualaTerengganuAreas.getAreaName(_selectedAreaId!);

    // Update BantuanProvider
    if (mounted) {
      await context
          .read<BantuanProvider>()
          .setManualArea(_selectedAreaId!, areaName);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          isMalay ? 'Pilih Lokasi' : 'Select Location',
          style: TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Icon(Icons.location_on, size: 64, color: AppColors.primaryBlue),
                const SizedBox(height: 12),
                Text(
                  isMalay ? 'Pilih Kawasan Anda' : 'Choose Your Area',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  isMalay
                      ? 'Detect automatik atau pilih manual'
                      : 'Auto detect or select manually',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── GPS Auto-Detect Button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _isDetectingGps ? null : () => _detectGpsLocation(isMalay),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _gpsDetectedAreaName != null
                      ? Colors.green.withOpacity(0.1)
                      : AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _gpsDetectedAreaName != null
                        ? Colors.green
                        : AppColors.primaryBlue,
                    width: 1.5,
                  ),
                ),
                child: _isDetectingGps
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isMalay
                                ? 'Mengesan lokasi...'
                                : 'Detecting location...',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _gpsDetectedAreaName != null
                                ? Icons.gps_fixed
                                : Icons.my_location,
                            color: _gpsDetectedAreaName != null
                                ? Colors.green
                                : AppColors.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _gpsDetectedAreaName != null
                                    ? (isMalay
                                        ? 'Lokasi Dikesan ✓'
                                        : 'Location Detected ✓')
                                    : (isMalay
                                        ? 'Guna Lokasi Semasa'
                                        : 'Use Current Location'),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _gpsDetectedAreaName != null
                                        ? Colors.green.shade700
                                        : AppColors.primaryBlue),
                              ),
                              if (_gpsDetectedAreaName != null)
                                Text(
                                  _gpsDetectedAreaName!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600),
                                )
                              else
                                Text(
                                  isMalay
                                      ? 'Auto detect kawasan terdekat'
                                      : 'Auto detect nearest area',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGrey),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Divider dengan label "ATAU"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(child: Divider(color: AppColors.lightGrey)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  isMalay ? 'ATAU PILIH MANUAL' : 'OR SELECT MANUALLY',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
              ),
              Expanded(child: Divider(color: AppColors.lightGrey)),
            ]),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: _filterAreas,
              decoration: InputDecoration(
                hintText:
                    isMalay ? 'Cari kawasan...' : 'Search area...',
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.backgroundBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Area List
          Expanded(
            child: _filteredAreas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off,
                            size: 64, color: AppColors.textGrey),
                        const SizedBox(height: 16),
                        Text(
                            isMalay
                                ? 'Tiada kawasan dijumpai'
                                : 'No areas found',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textGrey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredAreas.length,
                    itemBuilder: (context, index) {
                      final area = _filteredAreas[index];
                      final isSelected = _selectedAreaId == area.id;
                      final isGpsDetected =
                          _gpsDetectedAreaName == area.name;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue.withOpacity(0.1)
                              : AppColors.white,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.lightGrey,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            area.category == 'town'
                                ? Icons.location_city
                                : area.category == 'mukim'
                                    ? Icons.maps_home_work
                                    : Icons.location_on,
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.textGrey,
                          ),
                          title: Text(area.name,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.textDark)),
                          subtitle: Row(children: [
                            Text(
                              area.category == 'town'
                                  ? (isMalay
                                      ? 'Bandar Utama'
                                      : 'Main Town')
                                  : area.category == 'mukim'
                                      ? 'Mukim'
                                      : (isMalay
                                          ? 'Kawasan'
                                          : 'Area'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey),
                            ),
                            // Badge GPS kalau kawasan ni yang didetect
                            if (isGpsDetected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.green.shade300),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.gps_fixed,
                                          size: 10,
                                          color: Colors.green.shade700),
                                      const SizedBox(width: 3),
                                      Text(
                                        isMalay
                                            ? 'Lokasi anda'
                                            : 'Your location',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                Colors.green.shade700,
                                            fontWeight:
                                                FontWeight.w600),
                                      ),
                                    ]),
                              ),
                            ],
                          ]),
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: AppColors.primaryBlue)
                              : null,
                          onTap: () =>
                              setState(() => _selectedAreaId = area.id),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: CustomButton(
              text: isMalay ? 'Sahkan Lokasi' : 'Confirm Location',
              onPressed: () => _saveLocationAndContinue(isMalay),
            ),
          ),
        ],
      ),
    );
  }
}