// lib/models/location_model.dart

class LocationArea {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;

  const LocationArea({
    required this.id,
    required this.name,
    this.category = 'area',
    required this.latitude,
    required this.longitude,
  });
}

class KualaTerengganuAreas {
  static const List<LocationArea> areas = [
    LocationArea(id: 'kt_bandar',          name: 'Bandar Kuala Terengganu',  category: 'town',  latitude: 5.3296,  longitude: 103.1370),
    LocationArea(id: 'kt_batu_buruk',      name: 'Batu Buruk',               category: 'area',  latitude: 5.3150,  longitude: 103.1580),
    LocationArea(id: 'kt_bukit_besar',     name: 'Bukit Besar',              category: 'area',  latitude: 5.3400,  longitude: 103.1200),
    LocationArea(id: 'kt_chabang_tiga',    name: 'Chabang Tiga',             category: 'mukim', latitude: 5.3600,  longitude: 103.0900),
    LocationArea(id: 'kt_chendering',      name: 'Chendering',               category: 'area',  latitude: 5.2800,  longitude: 103.1500),
    LocationArea(id: 'kt_durian_burung',   name: 'Durian Burung',            category: 'area',  latitude: 5.3100,  longitude: 103.1100),
    LocationArea(id: 'kt_gong_badak',      name: 'Gong Badak',               category: 'mukim', latitude: 5.3900,  longitude: 103.0700),
    LocationArea(id: 'kt_kuala_ibai',      name: 'Kuala Ibai',               category: 'area',  latitude: 5.2950,  longitude: 103.1650),
    LocationArea(id: 'kt_ladang',          name: 'Ladang / Wakaf Mempelam',  category: 'area',  latitude: 5.3500,  longitude: 103.1050),
    LocationArea(id: 'kt_losong',          name: 'Losong',                   category: 'mukim', latitude: 5.3200,  longitude: 103.1100),
    LocationArea(id: 'kt_manir',           name: 'Manir',                    category: 'mukim', latitude: 5.3750,  longitude: 103.0600),
    LocationArea(id: 'kt_pengkalan_chepa', name: 'Pengkalan Chepa',          category: 'mukim', latitude: 5.4100,  longitude: 103.0550),
    LocationArea(id: 'kt_seberang_takir',  name: 'Seberang Takir',           category: 'mukim', latitude: 5.3700,  longitude: 103.1300),
    LocationArea(id: 'kt_kuala_nerus',     name: 'Kuala Nerus',              category: 'town',  latitude: 5.4300,  longitude: 103.0800),
    LocationArea(id: 'kt_tok_jembal',      name: 'Tok Jembal',               category: 'area',  latitude: 5.4000,  longitude: 103.0950),
  ];

  static String getAreaName(String id) {
    try {
      return areas.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return 'Kuala Terengganu';
    }
  }

  // ✅ Untuk map — get coordinates by area id
  static LocationArea? getAreaById(String id) {
    try {
      return areas.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}