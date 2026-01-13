import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return _auth.signInWithPopup(provider);
      }

      // google_sign_in on Android uses the Credential Manager-backed GIS flow when available.
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign-in aborted');
      }

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return _auth.signInWithCredential(credential);
    } catch (e, stackTrace) {
      print('❌ ERROR during Google Sign-In: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      print('🔄 Starting sign out process...');

      // On web, GoogleSignIn.signOut() requires a Client ID, so skip it
      if (!kIsWeb) {
        await _googleSignIn.signOut();
        print('✅ Google Sign-In signed out');
      }

      await _auth.signOut();
      print('✅ Firebase Auth signed out successfully');
    } catch (e, stackTrace) {
      print('❌ ERROR signing out: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }
}
