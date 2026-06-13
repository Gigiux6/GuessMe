import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('Errore signInAnonymously: $e');
      throw Exception('Errore durante l\'accesso anonimo: $e');
    }
  }

  Future<AuthCredential?> _getMobileGoogleCredential() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  Future<User?> linkWithGoogle() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Nessun utente attualmente autenticato.');
    }

    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        try {
          final UserCredential userCredential = await user.linkWithPopup(googleProvider);
          return userCredential.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Fallback: the Google account already exists, so log in with it.
            final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
            return userCredential.user;
          }
          rethrow;
        }
      } else {
        final credential = await _getMobileGoogleCredential();
        if (credential == null) return null;

        try {
          final UserCredential userCredential = await user.linkWithCredential(credential);
          return userCredential.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Fallback: the Google account already exists, so log in with it.
            final UserCredential userCredential = await _auth.signInWithCredential(credential);
            return userCredential.user;
          }
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('FirebaseAuthException in linkWithGoogle: ${e.code} - ${e.message}\n$stackTrace');
      if (e.code == 'provider-already-linked') {
        throw Exception('Questo profilo è già collegato ad un account Google.');
      } else {
        throw Exception('Errore durante il collegamento Google: ${e.message}');
      }
    } catch (e, stackTrace) {
      debugPrint('Errore generico in linkWithGoogle: $e\n$stackTrace');
      throw Exception('Errore generico durante il collegamento Google: $e');
    }
  }

  Future<User?> linkWithProviderCredential(AuthCredential credential) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Nessun utente attualmente autenticato.');
    }
    try {
      final UserCredential userCredential = await user.linkWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException in linkWithProviderCredential: ${e.code} - ${e.message}');
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        // Fallback: the account already exists, so log in with it.
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      } else if (e.code == 'provider-already-linked') {
        throw Exception('Questo profilo è già collegato ad un account con lo stesso provider.');
      } else {
        throw Exception('Errore durante il collegamento: ${e.message}');
      }
    } catch (e) {
      debugPrint('Errore generico in linkWithProviderCredential: $e');
      throw Exception('Errore generico durante il collegamento: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        final credential = await _getMobileGoogleCredential();
        if (credential == null) return null;

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      debugPrint('Errore in signInWithGoogle: $e');
      throw Exception('Errore durante l\'accesso con Google: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _googleSignIn!.signOut();
    }
  }
}
