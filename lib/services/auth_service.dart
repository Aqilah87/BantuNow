// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Create user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'user_id': userCredential.user!.uid,
        'name': name,
        'email': email,
        'num_phone': phone,
        'role': 'both', // Default role
        'availability_status': 'available',
        'created_at': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Account created successfully'};
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign in with email
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {'success': true, 'message': 'Login successful'};
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return {'success': false, 'message': 'Sign in cancelled'};
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Check if user exists in Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // If new user, save to Firestore
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'user_id': userCredential.user!.uid,
          'name': userCredential.user!.displayName ?? 'User',
          'email': userCredential.user!.email,
          'num_phone': userCredential.user!.phoneNumber ?? '',
          'role': 'both',
          'availability_status': 'available',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return {'success': true, 'message': 'Login successful'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}