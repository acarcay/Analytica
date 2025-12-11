import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/logging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // GoogleSignIn instance with proper initialization
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Google sign-in canceled by user',
        );
      }

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Sign in to Firebase with the Google credential
      final result = await _auth.signInWithCredential(credential);
      
      // Ensure user document exists in Firestore
      await _ensureUserDoc(result.user);
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signInWithApple() async {
    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final result = await _auth.signInWithCredential(oauthCredential);

      // Update display name if not set (Apple provides name only on first sign-in)
      if (result.user != null && 
          (result.user!.displayName == null || result.user!.displayName!.isEmpty)) {
        final given = appleCredential.givenName ?? '';
        final family = appleCredential.familyName ?? '';
        final name = ('$given $family').trim();
        
        if (name.isNotEmpty) {
          await result.user!.updateDisplayName(name);
        }
      }

      // Ensure user document exists in Firestore
      await _ensureUserDoc(result.user);
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> uploadProfilePhoto(String uid, File file) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      // Update Firestore and Firebase Auth profile
      await _db.collection('users').doc(uid).update({'photoURL': url});
      await _auth.currentUser?.updatePhotoURL(url);

      return url;
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors (e.g., storage not configured, permission denied)
      AppLog.e('uploadProfilePhoto FirebaseException: ${e.code} ${e.message}');
      // Return null so caller can show a friendly message rather than crash
      return null;
    } catch (e) {
      AppLog.e('uploadProfilePhoto unexpected error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}