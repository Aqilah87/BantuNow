// lib/screens/location/select_location_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/location_model.dart';
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

  void _filterAreas(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAreas = KualaTerengganuAreas.areas;
      } else {
        _filteredAreas = KualaTerengganuAreas.areas
            .where((area) => area.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _saveLocationAndContinue(bool isMalay) async {
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay ? 'Sila pilih kawasan anda' : 'Please select your area'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_area_id', _selectedAreaId!);
    await prefs.setString('user_area_name', KualaTerengganuAreas.getAreaName(_selectedAreaId!));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
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
          style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(Icons.location_on, size: 80, color: AppColors.primaryBlue),
                const SizedBox(height: 16),
                Text(
                  isMalay ? 'Pilih Kawasan Anda' : 'Choose Your Area',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  isMalay
                      ? 'Pilih kawasan anda di Kuala Terengganu untuk cari bantuan berdekatan'
                      : 'Select your area in Kuala Terengganu to find nearby help',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              onChanged: _filterAreas,
              decoration: InputDecoration(
                hintText: isMalay ? 'Cari kawasan...' : 'Search area...',
                prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.backgroundBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Area List
          Expanded(
            child: _filteredAreas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 64, color: AppColors.textGrey),
                        const SizedBox(height: 16),
                        Text(isMalay ? 'Tiada kawasan dijumpai' : 'No areas found',
                            style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredAreas.length,
                    itemBuilder: (context, index) {
                      final area = _filteredAreas[index];
                      final isSelected = _selectedAreaId == area.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : AppColors.lightGrey,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            area.category == 'town' ? Icons.location_city
                                : area.category == 'mukim' ? Icons.maps_home_work
                                : Icons.location_on,
                            color: isSelected ? AppColors.primaryBlue : AppColors.textGrey,
                          ),
                          title: Text(area.name,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppColors.primaryBlue : AppColors.textDark)),
                          subtitle: Text(
                            area.category == 'town'
                                ? (isMalay ? 'Bandar Utama' : 'Main Town')
                                : area.category == 'mukim'
                                    ? 'Mukim'
                                    : (isMalay ? 'Kawasan' : 'Area'),
                            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                          trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primaryBlue) : null,
                          onTap: () => setState(() => _selectedAreaId = area.id),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(24.0),
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