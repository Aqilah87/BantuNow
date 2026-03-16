// lib/services/bantuan_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bantuan_model.dart';

class BantuanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'bantuan';

  // ─── FETCH ALL (realtime stream) ───────────────────────────────────────────
  Stream<List<BantuanModel>> getBantuanStream({
    String? type,
    String? category,
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
      return snapshot.docs
          .map((doc) =>
              BantuanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // ─── UPLOAD IMAGE TO FIREBASE STORAGE ──────────────────────────────────────
  Future<String?> uploadImage(File imageFile, String uid) async {
    try {
      final fileName =
          'bantuan/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      return null;
    }
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

  // ─── CLOSE BANTUAN ──────────────────────────────────────────────────────────
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
  // ✅ FIX: Buang orderBy untuk elak index error, sort dalam app
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

      // Sort dalam app — terbaru dulu
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}