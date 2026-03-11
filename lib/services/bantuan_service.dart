// lib/services/bantuan_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bantuan_model.dart';

class BantuanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bantuan';

  // ─── FETCH ALL (realtime stream) ───────────────────────────────────────────
  Stream<List<BantuanModel>> getBantuanStream({
    String? type,       // 'request' / 'offer' / null = semua
    String? category,   // id kategori / null = semua
    String? areaId,     // id kawasan / null = semua
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .orderBy('created_at', descending: true);

    if (type != null && type != 'all') {
      query = query.where('type', isEqualTo: type);
    }

    if (category != null && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BantuanModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ─── ADD NEW BANTUAN ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addBantuan(BantuanModel bantuan) async {
    try {
      await _firestore.collection(_collection).add({
        ...bantuan.toMap(),
        'created_at': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'message': 'Bantuan berjaya dipost!'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── CLOSE/DELETE BANTUAN ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> closeBantuan(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({'status': 'closed'});
      return {'success': true, 'message': 'Bantuan ditutup'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET USER'S OWN BANTUAN ─────────────────────────────────────────────────
  Stream<List<BantuanModel>> getUserBantuan(String uid) {
    return _firestore
        .collection(_collection)
        .where('posted_by_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BantuanModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}