// lib/services/bantuan_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bantuan_model.dart';

class BantuanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'bantuan';

  // ── Auto-close config ──────────────────────────────────────────────
  // Post stuck in_progress auto-close selepas 7 hari
  static const int _autoCloseDays = 7;

  // ─── Auto-close check ──────────────────────────────────────────────
  Future<void> checkAndAutoClose() async {
    try {
      final cutoff =
          DateTime.now().subtract(const Duration(days: _autoCloseDays));

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
      // Silent fail — non-critical
    }
  }

  // ─── Streams ───────────────────────────────────────────────────────

  Stream<List<BantuanModel>> getBantuanStream({
    String? type,
    String? category,
  }) {
    // Tunjuk open, in_progress, DAN full dalam feed
    // 'full' = multiple slot offer yang dah penuh tapi masih relevan
    final Query query = _firestore
        .collection(_collection)
        .where('status', whereIn: ['open', 'in_progress', 'full'])
        .orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => BantuanModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
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
          .map((doc) => BantuanModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─── Mutations ─────────────────────────────────────────────────────

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

  // ─── ACCEPT HELP ───────────────────────────────────────────────────
  //
  // SINGLE offer / REQUEST:
  //   → status = 'in_progress', helper_uid, helper_name
  //
  // MULTIPLE offer:
  //   → accepted_slots + 1
  //   → helper_uids[] tambah uid
  //   → helper_names[] tambah name
  //   → status KEKAL 'open' selagi slot ada
  //   → bila accepted_slots == total_slots → status = 'full'

  Future<Map<String, dynamic>> acceptSingleHelp({
    required String postId,
    required String helperUid,
    required String helperName,
  }) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'status': 'in_progress',
        'helper_uid': helperUid,
        'helper_name': helperName,
        'helper_confirmed': false,
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptMultipleSlot({
    required String postId,
    required String helperUid,
    required String helperName,
    required int currentAccepted,
    required int totalSlots,
  }) async {
    try {
      // Semak dulu — double-accept prevention
      final doc =
          await _firestore.collection(_collection).doc(postId).get();
      if (!doc.exists) {
        return {'success': false, 'message': 'Post tidak wujud'};
      }

      final data = doc.data()!;
      final existingUids =
          List<String>.from(data['helper_uids'] ?? []);

      if (existingUids.contains(helperUid)) {
        return {
          'success': false,
          'message': 'already_joined',
        };
      }

      final latestAccepted =
          (data['accepted_slots'] as num?)?.toInt() ?? 0;

      if (latestAccepted >= totalSlots) {
        return {'success': false, 'message': 'slot_full'};
      }

      final newAccepted = latestAccepted + 1;
      final isFull = newAccepted >= totalSlots;

      await _firestore.collection(_collection).doc(postId).update({
        'accepted_slots': newAccepted,
        'helper_uids': FieldValue.arrayUnion([helperUid]),
        'helper_names': FieldValue.arrayUnion([helperName]),
        // Kalau penuh → tukar status ke 'full', kalau tidak kekal 'open'
        'status': isFull ? 'full' : 'open',
      });

      return {
        'success': true,
        'is_full': isFull,
        'remaining': totalSlots - newAccepted,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── HELPER CONFIRM ────────────────────────────────────────────────
  // Untuk SINGLE: sama seperti dulu
  // Untuk MULTIPLE: simpan timestamp confirm individual (guna subcollection kalau perlu, buat simple dulu)

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