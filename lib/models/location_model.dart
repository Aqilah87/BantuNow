// lib/models/location_model.dart

class LocationArea {
  final String id;
  final String name;
  final String category; // 'mukim', 'town', 'area'

  LocationArea({
    required this.id,
    required this.name,
    required this.category,
  });
}

// Kuala Terengganu Districts/Areas
class KualaTerengganuAreas {
  static final List<LocationArea> areas = [
    // Main Towns / Bandar Utama
    LocationArea(id: '001', name: 'Kuala Terengganu (Bandar)', category: 'town'),
    LocationArea(id: '002', name: 'Kuala Nerus', category: 'town'),
    
    // Mukims (Sub-districts)
    LocationArea(id: '101', name: 'Mukim Batu Buruk', category: 'mukim'),
    LocationArea(id: '102', name: 'Mukim Pulau Kambing', category: 'mukim'),
    LocationArea(id: '103', name: 'Mukim Ladang', category: 'mukim'),
    LocationArea(id: '104', name: 'Mukim Tanjung', category: 'mukim'),
    
    // Popular Areas / Kawasan Popular
    LocationArea(id: '201', name: 'Gong Badak', category: 'area'),
    LocationArea(id: '202', name: 'Chendering', category: 'area'),
    LocationArea(id: '203', name: 'Cabang Tiga', category: 'area'),
    LocationArea(id: '204', name: 'Losong', category: 'area'),
    LocationArea(id: '205', name: 'Tok Jembal', category: 'area'),
    LocationArea(id: '206', name: 'Bukit Tunggal', category: 'area'),
    LocationArea(id: '207', name: 'Seberang Takir', category: 'area'),
    LocationArea(id: '208', name: 'Kampung Ladang', category: 'area'),
    LocationArea(id: '209', name: 'Batu Rakit', category: 'area'),
    LocationArea(id: '210', name: 'Kampung Mangkok', category: 'area'),
    LocationArea(id: '211', name: 'Teluk Ketapang', category: 'area'),
    LocationArea(id: '212', name: 'Kampung Mengabang Telipot', category: 'area'),
    LocationArea(id: '213', name: 'Kampung Baru', category: 'area'),
    LocationArea(id: '214', name: 'Kuala Ibai', category: 'area'),
    LocationArea(id: '215', name: 'Bandar Al-Muktafi Billah Shah', category: 'area'),
    LocationArea(id: '216', name: 'Gong Pauh', category: 'area'),
    LocationArea(id: '217', name: 'Wakaf Tembesu', category: 'area'),
    LocationArea(id: '218', name: 'Bukit Payong', category: 'area'),
    LocationArea(id: '219', name: 'Manir', category: 'area'),
    LocationArea(id: '220', name: 'Kampung Raja', category: 'area'),
    LocationArea(id: '221', name: 'Taman Desa Cempaka', category: 'area'),
    LocationArea(id: '222', name: 'Taman Cendering Jaya', category: 'area'),
    LocationArea(id: '223', name: 'Taman Bendahara', category: 'area'),
    
    // Educational/Institutional Areas
    LocationArea(id: '301', name: 'UMT (Universiti Malaysia Terengganu)', category: 'area'),
    LocationArea(id: '302', name: 'UNISZA (Universiti Sultan Zainal Abidin)', category: 'area'),
    LocationArea(id: '303', name: 'Kompleks Kementerian', category: 'area'),
    
    // Commercial/Shopping Areas
    LocationArea(id: '401', name: 'Pasar Payang', category: 'area'),
    LocationArea(id: '402', name: 'Chinatown', category: 'area'),
    LocationArea(id: '403', name: 'Mesra Mall', category: 'area'),
    LocationArea(id: '404', name: 'Billion Shopping Centre', category: 'area'),
  ];

  // Get area name by ID
  static String getAreaName(String id) {
    try {
      return areas.firstWhere((area) => area.id == id).name;
    } catch (e) {
      return 'Unknown Area';
    }
  }

  // Get areas by category
  static List<LocationArea> getAreasByCategory(String category) {
    return areas.where((area) => area.category == category).toList();
  }
}