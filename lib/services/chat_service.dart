// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final _firestore = FirebaseFirestore.instance;

  // ─── Generate consistent conversation ID ──────────────────────────
  // Sort UIDs supaya A-B dan B-A generate ID yang sama
  String _conversationId(String uid1, String uid2, String bantuanId) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}_$bantuanId';
  }

  // ─── Get or create conversation ───────────────────────────────────
  Future<String> getOrCreateConversation({
    required String otherUid,
    required String otherName,
    required String bantuanId,
    required String bantuanTitle,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final convId =
        _conversationId(currentUser.uid, otherUid, bantuanId);

    final convRef = _firestore.collection('chats').doc(convId);
    final convDoc = await convRef.get();

    if (!convDoc.exists) {
      // Fetch current user name
      String currentName = currentUser.displayName ?? 'User';
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          currentName = userDoc.data()?['name'] ?? currentName;
        }
      } catch (_) {}

      await convRef.set({
        'conversation_id': convId,
        'participants': [currentUser.uid, otherUid],
        'participant_names': {
          currentUser.uid: currentName,
          otherUid: otherName,
        },
        'bantuan_id': bantuanId,
        'bantuan_title': bantuanTitle,
        'last_message': '',
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sender': '',
        'created_at': FieldValue.serverTimestamp(),
        'unread_count': {
          currentUser.uid: 0,
          otherUid: 0,
        },
      });
    }

    return convId;
  }

  // ─── Send text message ─────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String type = 'text', // 'text' | 'location'
    Map<String, dynamic>? locationData,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final convRef =
    _firestore.collection('chats').doc(conversationId);

    final messageData = {
      'sender_uid': currentUser.uid,
      'text': text,
      'type': type,
      'created_at': FieldValue.serverTimestamp(),
      'read_by': [currentUser.uid],
    };

    if (type == 'location' && locationData != null) {
      messageData['location'] = locationData as dynamic;
    }

    // Add message
    await convRef.collection('messages').add(messageData);

    // Update conversation last message
    final convDoc = await convRef.get();
    if (convDoc.exists) {
      final data = convDoc.data()!;
      final participants =
          List<String>.from(data['participants'] ?? []);
      // Increment unread for other participants
      final unreadUpdate = <String, dynamic>{};
      for (final uid in participants) {
        if (uid != currentUser.uid) {
          unreadUpdate['unread_count.$uid'] = FieldValue.increment(1);
        }
      }

      await convRef.update({
        'last_message': type == 'location'
            ? '📍 ${locationData?['address'] ?? 'Lokasi'}'
            : text,
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sender': currentUser.uid,
        ...unreadUpdate,
      });
    }
  }

  // ─── Send location message ────────────────────────────────────────
  Future<void> sendLocation({
    required String conversationId,
    required double lat,
    required double lon,
    required String address,
  }) async {
    await sendMessage(
      conversationId: conversationId,
      text: '📍 $address',
      type: 'location',
      locationData: {
        'lat': lat,
        'lon': lon,
        'address': address,
      },
    );
  }

  // ─── Send system message (auto-generated, no sender) ──────────────
  // systemType: 'reject' | 'withdraw' | null (general/neutral system message)
  Future<void> sendSystemMessage({
    required String conversationId,
    required String message,
    String? systemType,
  }) async {
    final convRef = _firestore.collection('chats').doc(conversationId);

    await convRef.collection('messages').add({
      'sender_uid': 'system',
      'text': message,
      'type': 'system',
      if (systemType != null) 'system_type': systemType,
      'created_at': FieldValue.serverTimestamp(),
      'read_by': [],
    });

    await convRef.update({
      'last_message': message,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_sender': 'system',
    });
  }

  // ─── Mark messages as read ────────────────────────────────────────
  Future<void> markAsRead(String conversationId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .update({
      'unread_count.${currentUser.uid}': 0,
    });
  }

  // ─── Streams ───────────────────────────────────────────────────────

  /// Stream semua conversations untuk current user
  Stream<List<Map<String, dynamic>>> getConversationsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  /// Stream messages dalam satu conversation
  Stream<List<Map<String, dynamic>>> getMessagesStream(
      String conversationId) {
    return _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  /// Total unread count untuk current user (untuk badge)
  Stream<int> getTotalUnreadStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final unread = doc.data()['unread_count'] as Map?;
        total +=
            ((unread?[currentUser.uid] as num?)?.toInt() ?? 0);
      }
      return total;
    });
  }

  // ─── Get other participant info ───────────────────────────────────
  String getOtherUid(Map<String, dynamic> conversation) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final participants =
        List<String>.from(conversation['participants'] ?? []);
    return participants.firstWhere((uid) => uid != currentUid,
        orElse: () => '');
  }

  String getOtherName(Map<String, dynamic> conversation) {
    final otherUid = getOtherUid(conversation);
    final names =
        conversation['participant_names'] as Map<String, dynamic>?;
    return names?[otherUid] ?? 'User';
  }

  int getUnreadCount(Map<String, dynamic> conversation) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final unread =
        conversation['unread_count'] as Map<String, dynamic>?;
    return (unread?[currentUid] as num?)?.toInt() ?? 0;
  }
}