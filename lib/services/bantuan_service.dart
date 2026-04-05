// lib/services/bantuan_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bantuan_model.dart';

class BantuanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'bantuan';

  // ✅ FIX: Filter type & category client-side — elak composite index error
  Stream<List<BantuanModel>> getBantuanStream({
    String? type,
    String? category,
  }) {
    // Query simple — status + orderBy je (index dah ada)
    final Query query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) =>
              BantuanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // ✅ Filter type client-side
      if (type != null && type != 'all') {
        list = list.where((p) => p.type == type).toList();
      }

      // ✅ Filter category client-side
      if (category != null && category != 'all') {
        list = list.where((p) => p.category == category).toList();
      }

      return list;
    });
  }

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
}