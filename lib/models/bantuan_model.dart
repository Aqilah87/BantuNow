// lib/models/bantuan_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BantuanModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String area;
  final String areaId;
  final String status;
  final String type;
  final String postedBy;
  final String postedByUid;
  final String? whatsapp;
  final String? imageUrl;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

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
    this.whatsapp,
    this.imageUrl,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  factory BantuanModel.fromMap(Map<String, dynamic> map, String id) {
    return BantuanModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'lain',
      area: map['area'] ?? '',
      areaId: map['area_id'] ?? '',
      status: map['status'] ?? 'open',
      type: map['type'] ?? 'request',
      postedBy: map['posted_by'] ?? '',
      postedByUid: map['posted_by_uid'] ?? '',
      whatsapp: map['whatsapp'],
      imageUrl: map['image_url'],
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
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
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (imageUrl != null) 'image_url': imageUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

// ─── Categories ───────────────────────────────────────────────────────────────
class BantuanCategories {
  static const List<Map<String, String>> categories = [
    {'id': 'makanan', 'name': 'Makanan / Food', 'icon': '🍱'},
    {'id': 'transport', 'name': 'Transport / Ride', 'icon': '🚗'},
    {'id': 'perubatan', 'name': 'Perubatan / Medical', 'icon': '🏥'},
    {'id': 'pendidikan', 'name': 'Pendidikan / Education', 'icon': '📚'},
    {'id': 'kewangan', 'name': 'Kewangan / Financial', 'icon': '💰'},
    {'id': 'rumah', 'name': 'Rumah / Housing', 'icon': '🏠'},
    {'id': 'kerja', 'name': 'Kerja / Employment', 'icon': '💼'},
    {'id': 'lain', 'name': 'Lain-lain / Others', 'icon': '🤝'},
  ];

  static String getCategoryName(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'name': 'Lain-lain / Others', 'icon': '🤝'},
    );
    return cat['name']!;
  }

  static String getCategoryIcon(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'name': 'Lain-lain / Others', 'icon': '🤝'},
    );
    return cat['icon']!;
  }
}