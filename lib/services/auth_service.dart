import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn _googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: '374105398036-jq56psub2vc0tdh7kgnilr1d4pllpm01.apps.googleusercontent.com',
    );
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'canceled', message: 'Google sign-in canceled');
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user);
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(oauthCredential);
    if (result.user != null && (result.user!.displayName == null || result.user!.displayName!.isEmpty)) {
      final given = appleCredential.givenName ?? '';
      final family = appleCredential.familyName ?? '';
      final name = (given + ' ' + family).trim();
      if (name.isNotEmpty) {
        await result.user!.updateDisplayName(name);
      }
    }
    await _ensureUserDoc(result.user);
    return result;
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
    final storageRef = FirebaseStorage.instance.ref().child('profile_photos').child('$uid.jpg');
    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoURL': url});
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }
}


