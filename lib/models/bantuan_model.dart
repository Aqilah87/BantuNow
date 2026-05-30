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

  // ── Pin lokasi tepat ──────────────────────────────────────────────
  final double? pinLat;
  final double? pinLon;
  final String? pinAddress;

  // ── Single helper (untuk single offer / request) ──────────────────
  final String? helperUid;
  final String? helperName;
  final bool helperConfirmed;
  final String? posterAvailability;

  // ── Slot system (untuk KEDUA-DUA offer DAN request) ──────────────
  //
  // offerType      : 'single' | 'multiple'
  //                  → apply untuk request DAN offer
  //                  → request pun boleh perlukan ramai org (angkat barang, dll)
  //
  // completionType : 'individual' | 'group'
  //                  → hanya relevan bila offerType == 'multiple'
  //                  → 'individual' : helpers datang satu-satu, setiap satu confirm sendiri
  //                  → 'group'      : semua datang serentak, owner je yang close
  //
  // totalSlots     : hanya relevan bila offerType == 'multiple'
  // acceptedSlots  : berapa ramai yang dah accept (auto-increment)
  // helperUids     : list uid yang dah join (multiple)
  // helperNames    : list nama yang dah join (multiple)
  final String offerType;
  final String completionType;
  final int? totalSlots;
  final int acceptedSlots;
  final List<String> helperUids;
  final List<String> helperNames;

  // ── Per-helper confirmation (untuk multiple + individual) ─────────
  // helperConfirmations : { "uid_A": true, "uid_B": false, ... }
  // Hanya digunakan bila completionType == 'individual'
  // Untuk 'group', owner terus close tanpa tunggu setiap helper confirm
  final Map<String, bool> helperConfirmations;

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
    this.pinLat,
    this.pinLon,
    this.pinAddress,
    this.helperUid,
    this.helperName,
    this.helperConfirmed = false,
    this.posterAvailability,
    this.offerType = 'single',
    this.completionType = 'individual',
    this.totalSlots,
    this.acceptedSlots = 0,
    this.helperUids = const [],
    this.helperNames = const [],
    this.helperConfirmations = const {},
  });

  // ── Getters ───────────────────────────────────────────────────────

  /// Post ini guna sistem multiple slot?
  bool get isMultipleSlot => offerType == 'multiple';

  /// Helpers datang satu-satu dan confirm secara individu?
  bool get isIndividualCompletion => completionType == 'individual';

  /// Helpers datang serentak, owner yang close?
  bool get isGroupCompletion => completionType == 'group';

  /// Masih ada slot kosong?
  bool get hasAvailableSlot {
    if (!isMultipleSlot) return status == 'open';
    if (totalSlots == null) return true;
    return acceptedSlots < totalSlots!;
  }

  /// Berapa slot lagi tinggal
  int get remainingSlots {
    if (!isMultipleSlot || totalSlots == null) return 0;
    return (totalSlots! - acceptedSlots).clamp(0, totalSlots!);
  }

  /// Berapa ramai helper yang dah confirm selesai (multiple + individual)
  int get confirmedCount =>
      helperConfirmations.values.where((v) => v == true).length;

  /// Semua helper dalam helperUids dah confirm? (multiple + individual)
  bool get allHelpersConfirmed =>
      helperUids.isNotEmpty &&
      helperUids.every((uid) => helperConfirmations[uid] == true);

  factory BantuanModel.fromMap(Map<String, dynamic> map, String id) {
    // Parse helperConfirmations dari Firestore map
    Map<String, bool> parseConfirmations(dynamic raw) {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return {};
    }

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
      pinLat: (map['pin_lat'] as num?)?.toDouble(),
      pinLon: (map['pin_lon'] as num?)?.toDouble(),
      pinAddress: map['pin_address'],
      helperUid: map['helper_uid'],
      helperName: map['helper_name'],
      helperConfirmed: map['helper_confirmed'] ?? false,
      posterAvailability: map['poster_availability'],
      offerType: map['offer_type'] ?? 'single',
      completionType: map['completion_type'] ?? 'individual',
      totalSlots: (map['total_slots'] as num?)?.toInt(),
      acceptedSlots: (map['accepted_slots'] as num?)?.toInt() ?? 0,
      helperUids: List<String>.from(map['helper_uids'] ?? []),
      helperNames: List<String>.from(map['helper_names'] ?? []),
      helperConfirmations: parseConfirmations(map['helper_confirmations']),
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
      if (pinLat != null) 'pin_lat': pinLat,
      if (pinLon != null) 'pin_lon': pinLon,
      if (pinAddress != null) 'pin_address': pinAddress,
      if (helperUid != null) 'helper_uid': helperUid,
      if (helperName != null) 'helper_name': helperName,
      'helper_confirmed': helperConfirmed,
      if (posterAvailability != null)
        'poster_availability': posterAvailability,
      'offer_type': offerType,
      'completion_type': completionType,
      if (totalSlots != null) 'total_slots': totalSlots,
      'accepted_slots': acceptedSlots,
      'helper_uids': helperUids,
      'helper_names': helperNames,
      'helper_confirmations': helperConfirmations,
    };
  }
}

// ─── Categories ────────────────────────────────────────────────────────────────

class BantuanCategories {
  // defaultOfferType:
  //   'multiple' → auto-set slot bila user pilih kategori ni
  //   'single'   → auto-set satu orang bila user pilih kategori ni
  //
  // defaultCompletionType (hanya relevan bila multiple):
  //   'individual' → helpers datang satu-satu, confirm sendiri
  //   'group'      → semua datang serentak, owner close

  static const List<Map<String, String>> categories = [
    {
      'id': 'makanan',
      'name': 'Makanan & Minuman / Food',
      'icon': '🍱',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'transport',
      'name': 'Transport / Ride',
      'icon': '🚗',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'perubatan',
      'name': 'Perubatan / Medical',
      'icon': '🏥',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'repair',
      'name': 'Repair / Baiki',
      'icon': '🔧',
      'defaultOfferType': 'multiple',
      'defaultCompletionType': 'group',
    },
    {
      'id': 'angkat_barang',
      'name': 'Angkat Barang / Moving',
      'icon': '📦',
      'defaultOfferType': 'multiple',
      'defaultCompletionType': 'group',
    },
    {
      'id': 'pendidikan',
      'name': 'Pendidikan / Education',
      'icon': '📚',
      'defaultOfferType': 'multiple',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'kerja',
      'name': 'Kerja / Employment',
      'icon': '💼',
      'defaultOfferType': 'multiple',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'kewangan',
      'name': 'Kewangan / Financial',
      'icon': '💰',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'kecemasan',
      'name': 'Kecemasan / Emergency',
      'icon': '🚨',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
    {
      'id': 'lain',
      'name': 'Lain-lain / Others',
      'icon': '🤝',
      'defaultOfferType': 'single',
      'defaultCompletionType': 'individual',
    },
  ];

  static String getCategoryName(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {
        'name': 'Lain-lain / Others',
        'icon': '🤝',
        'defaultOfferType': 'single',
        'defaultCompletionType': 'individual',
      },
    );
    return cat['name']!;
  }

  static String getCategoryIcon(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {
        'name': 'Lain-lain / Others',
        'icon': '🤝',
        'defaultOfferType': 'single',
        'defaultCompletionType': 'individual',
      },
    );
    return cat['icon']!;
  }

  static String getDefaultOfferType(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {
        'name': 'Lain-lain / Others',
        'icon': '🤝',
        'defaultOfferType': 'single',
        'defaultCompletionType': 'individual',
      },
    );
    return cat['defaultOfferType'] ?? 'single';
  }

  static String getDefaultCompletionType(String id) {
    final cat = categories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {
        'name': 'Lain-lain / Others',
        'icon': '🤝',
        'defaultOfferType': 'single',
        'defaultCompletionType': 'individual',
      },
    );
    return cat['defaultCompletionType'] ?? 'individual';
  }
}