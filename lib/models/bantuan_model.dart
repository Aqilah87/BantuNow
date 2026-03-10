// lib/models/bantuan_model.dart

class BantuanModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String area;
  final String areaId;
  final String status; // 'open', 'in_progress', 'closed'
  final String type; // 'request' = minta bantuan, 'offer' = tawar bantuan
  final String postedBy;
  final String postedByUid;
  final DateTime createdAt;

  BantuanModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.area,
    required this.areaId,
    required this.status,
    required this.type,
    required this.postedBy,
    required this.postedByUid,
    required this.createdAt,
  });

  factory BantuanModel.fromMap(Map<String, dynamic> map, String id) {
    return BantuanModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      area: map['area'] ?? '',
      areaId: map['area_id'] ?? '',
      status: map['status'] ?? 'open',
      type: map['type'] ?? 'request',
      postedBy: map['posted_by'] ?? '',
      postedByUid: map['posted_by_uid'] ?? '',
      createdAt: map['created_at'] != null
          ? (map['created_at'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'area': area,
      'area_id': areaId,
      'status': status,
      'type': type,
      'posted_by': postedBy,
      'posted_by_uid': postedByUid,
      'created_at': createdAt,
    };
  }
}

// Kategori bantuan
class BantuanCategories {
  static const List<Map<String, dynamic>> categories = [
    {'id': 'makanan', 'name': 'Makanan / Food', 'icon': '🍚'},
    {'id': 'pengangkutan', 'name': 'Pengangkutan / Transport', 'icon': '🚗'},
    {'id': 'perubatan', 'name': 'Perubatan / Medical', 'icon': '🏥'},
    {'id': 'kewangan', 'name': 'Kewangan / Financial', 'icon': '💰'},
    {'id': 'pendidikan', 'name': 'Pendidikan / Education', 'icon': '📚'},
    {'id': 'rumah', 'name': 'Rumah / Housing', 'icon': '🏠'},
    {'id': 'lain', 'name': 'Lain-lain / Others', 'icon': '🤝'},
  ];

  static String getCategoryName(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'name': 'Lain-lain'},
    );
    return cat['name'];
  }

  static String getCategoryIcon(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'icon': '🤝'},
    );
    return cat['icon'];
  }
}