// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String numPhone;
  final String role;
  final String availabilityStatus;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.numPhone,
    required this.role,
    required this.availabilityStatus,
    required this.createdAt,
  });

  // From Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      numPhone: data['num_phone'] ?? '',
      role: data['role'] ?? 'both',
      availabilityStatus: data['availability_status'] ?? 'available',
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'num_phone': numPhone,
      'role': role,
      'availability_status': availabilityStatus,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}