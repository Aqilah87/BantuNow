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
    // 'full' = multiple slot yang dah penuh tapi masih relevan
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
  // SINGLE (offer atau request):
  //   → status = 'in_progress', set helper_uid, helper_name
  //
  // MULTIPLE (offer atau request):
  //   → accepted_slots + 1
  //   → helper_uids[] tambah uid
  //   → helper_names[] tambah name
  //   → init helper_confirmations[uid] = false (untuk individual)
  //   → status KEKAL 'open' selagi slot ada
  //   → bila penuh → status = 'full'

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
    required String completionType,
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
        return {'success': false, 'message': 'already_joined'};
      }

      final latestAccepted =
          (data['accepted_slots'] as num?)?.toInt() ?? 0;

      if (latestAccepted >= totalSlots) {
        return {'success': false, 'message': 'slot_full'};
      }

      final newAccepted = latestAccepted + 1;
      final isFull = newAccepted >= totalSlots;

      final updateData = <String, dynamic>{
        'accepted_slots': newAccepted,
        'helper_uids': FieldValue.arrayUnion([helperUid]),
        'helper_names': FieldValue.arrayUnion([helperName]),
        'status': isFull ? 'full' : 'open',
      };

      // Init confirmation entry hanya untuk individual
      // Group tak perlu — owner terus close
      if (completionType == 'individual') {
        updateData['helper_confirmations.$helperUid'] = false;
      }

      await _firestore
          .collection(_collection)
          .doc(postId)
          .update(updateData);

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
  //
  // SINGLE:
  //   → update boolean helper_confirmed = true
  //
  // MULTIPLE + INDIVIDUAL:
  //   → update helper_confirmations.<uid> = true (dot notation)
  //
  // MULTIPLE + GROUP:
  //   → helpers tak perlu confirm, owner terus close
  //   → function ini tak patut dipanggil untuk group
  //   → tapi kalau dipanggil jugak, treat sama macam individual

  Future<Map<String, dynamic>> helperConfirm(
    String id, {
    String? helperUid,
    bool isMultiple = false,
  }) async {
    try {
      if (isMultiple && helperUid != null) {
        // Per-helper confirmation menggunakan dot notation
        await _firestore.collection(_collection).doc(id).update({
          'helper_confirmations.$helperUid': true,
          'helper_confirmed_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Single — kekal sama
        await _firestore.collection(_collection).doc(id).update({
          'helper_confirmed': true,
          'helper_confirmed_at': FieldValue.serverTimestamp(),
        });
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── CLOSE BANTUAN ────────────────────────────────────────────────
  // Owner tutup post — untuk multiple (sama ada individual atau group)

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

  // ─── OWNER CANCEL / REJECT HELPER ─────────────────────────────────
  //
  // Owner boleh reject/cancel helper yang ada.
  //
  // SINGLE:
  //   → clear helper_uid, helper_name, helper_confirmed
  //   → status balik 'open'
  //
  // MULTIPLE:
  //   → remove uid & name dari arrays
  //   → buang entry dari helper_confirmations map (kalau ada)
  //   → accepted_slots - 1
  //   → status balik 'open' (walaupun sebelum ni 'full')

    Future<Map<String, dynamic>> ownerCancelHelper({
      required String postId,
      required String helperUid,
      required String helperName,
      required bool isMultiple,
      bool isIndividual = true,
      String? reason,
    }) async {

    try {
      if (isMultiple) {
        final doc =
            await _firestore.collection(_collection).doc(postId).get();
        if (!doc.exists) {
          return {'success': false, 'message': 'Post tidak wujud'};
        }

        final data = doc.data()!;
        final currentAccepted =
            (data['accepted_slots'] as num?)?.toInt() ?? 0;
        final newAccepted =
            (currentAccepted - 1).clamp(0, currentAccepted);

        final updateData = <String, dynamic>{
          'accepted_slots': newAccepted,
          'helper_uids': FieldValue.arrayRemove([helperUid]),
          'helper_names': FieldValue.arrayRemove([helperName]),
          'status': 'open',
        };

        // Buang entry confirmation — guna null instead of delete
        // FieldValue.delete() pada dot notation tak work untuk non-owner
        if (isIndividual) {
          updateData['helper_confirmations.$helperUid'] = null;
        }
        if (reason != null) {
          updateData['last_action_reason'] = reason;
        }

        await _firestore
            .collection(_collection)
            .doc(postId)
            .update(updateData);
      } else {
        // Single — clear semua helper fields
        await _firestore.collection(_collection).doc(postId).update({
          'status': 'open',
          'helper_uid': FieldValue.delete(),
          'helper_name': FieldValue.delete(),
          'helper_confirmed': false,
          'helper_confirmed_at': FieldValue.delete(),
          if (reason != null) 'last_action_reason': reason,
        });
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── HELPER WITHDRAW ──────────────────────────────────────────────
  //
  // Helper tarik diri sendiri dari post.
  // Logic sama seperti ownerCancelHelper.

  Future<Map<String, dynamic>> helperWithdraw({
    required String postId,
    required String helperUid,
    required String helperName,
    required bool isMultiple,
    bool isIndividual = true,
    String? reason,
  }) async {
    return ownerCancelHelper(
      postId: postId,
      helperUid: helperUid,
      helperName: helperName,
      isMultiple: isMultiple,
      isIndividual: isIndividual,
      reason: reason,
    );
  }
}