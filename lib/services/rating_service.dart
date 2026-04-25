// lib/services/rating_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  final _firestore = FirebaseFirestore.instance;

  // Submit rating untuk post yang dah selesai
  Future<Map<String, dynamic>> submitRating({
    required String bantuanId,
    required String ratedUserUid,
    required double rating,
    required String comment,
    required String type, // 'helper' atau 'requester'
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {'success': false, 'message': 'Not logged in'};

      // Check kalau dah pernah rate
      final existing = await _firestore
          .collection('ratings')
          .where('bantuan_id', isEqualTo: bantuanId)
          .where('rated_by_uid', isEqualTo: currentUser.uid)
          .get();

      if (existing.docs.isNotEmpty) {
        return {'success': false, 'message': 'Anda sudah memberi rating'};
      }

      // Simpan rating
      await _firestore.collection('ratings').add({
        'bantuan_id': bantuanId,
        'rated_user_uid': ratedUserUid,
        'rated_by_uid': currentUser.uid,
        'rating': rating,
        'comment': comment,
        'type': type,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update average rating dalam users collection
      await _updateUserRating(ratedUserUid);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Kira dan update average rating user
  Future<void> _updateUserRating(String userUid) async {
    final ratings = await _firestore
        .collection('ratings')
        .where('rated_user_uid', isEqualTo: userUid)
        .get();

    if (ratings.docs.isEmpty) return;

    double total = 0;
    for (final doc in ratings.docs) {
      total += (doc.data()['rating'] as num).toDouble();
    }
    final average = total / ratings.docs.length;

    await _firestore.collection('users').doc(userUid).update({
      'rating': double.parse(average.toStringAsFixed(1)),
      'rating_count': ratings.docs.length,
    });
  }

  // Get semua ratings untuk seorang user
  Stream<List<Map<String, dynamic>>> getUserRatings(String userUid) {
    return _firestore
        .collection('ratings')
        .where('rated_user_uid', isEqualTo: userUid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }
}