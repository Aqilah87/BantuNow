// lib/services/bantuan_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bantuan_model.dart';

class BantuanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'bantuan';

  // ── Auto-close config ────────────────────────────────────────────────────────
  // Post yang stuck dalam in_progress akan auto-close selepas 7 hari
  // dari masa helper_confirmed = true
  static const int _autoCloseDays = 7;

  // ─── Auto-close check ────────────────────────────────────────────────────────
  // Dipanggil bila user buka app / screen — check & close post yang stuck
  Future<void> checkAndAutoClose() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: _autoCloseDays));

      // Cari semua post in_progress yang helper dah confirm
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'in_progress')
          .where('helper_confirmed', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      int count = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Guna helper_confirmed_at kalau ada, fallback ke created_at
        DateTime? confirmedAt;
        if (data['helper_confirmed_at'] != null) {
          confirmedAt =
              (data['helper_confirmed_at'] as Timestamp).toDate();
        } else if (data['created_at'] != null) {
          confirmedAt = (data['created_at'] as Timestamp).toDate();
        }

        if (confirmedAt != null && confirmedAt.isBefore(cutoff)) {
          batch.update(doc.reference, {
            'status': 'closed',
            'auto_closed': true,
            'auto_closed_at': FieldValue.serverTimestamp(),
          });
          count++;
        }
      }

      if (count > 0) await batch.commit();
    } catch (e) {
      // Silent fail — auto-close is non-critical
    }
  }

  // ─── Streams ─────────────────────────────────────────────────────────────────

  // ✅ Filter type & category client-side — elak composite index error
  Stream<List<BantuanModel>> getBantuanStream({
    String? type,
    String? category,
  }) {
    // ✅ Show open AND in_progress posts in feed
    // (in_progress masih relevan untuk orang lain tahu post ni sedang dibantu)
    final Query query = _firestore
        .collection(_collection)
        .where('status', whereIn: ['open', 'in_progress'])
        .orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) =>
              BantuanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (type != null && type != 'all') {
        list = list.where((p) => p.type == type).toList();
      }

      if (category != null && category != 'all') {
        list = list.where((p) => p.category == category).toList();
      }

      return list;
    });
  }

  Stream<List<BantuanModel>> getUserBantuan(String uid) {
    return _firestore
        .collection(_collection)
        .where('posted_by_uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) =>
              BantuanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─── Mutations ───────────────────────────────────────────────────────────────

  Future<String?> uploadImage(File imageFile, String uid) async {
    try {
      final fileName =
          'bantuan/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

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

  Future<Map<String, dynamic>> updateBantuan(
      String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(id).update(data);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ Simpan timestamp bila helper confirm — digunakan untuk auto-close countdown
  Future<Map<String, dynamic>> helperConfirm(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'helper_confirmed': true,
        'helper_confirmed_at': FieldValue.serverTimestamp(),
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> closeBantuan(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'status': 'closed',
        'closed_at': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'message': 'Bantuan ditutup'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}