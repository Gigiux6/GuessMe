import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  
  /// Esegue la ri-autenticazione dell'utente prima di eseguire un'operazione sensibile.
  /// Ritorna [true] se la ri-autenticazione ha avuto successo, [false] altrimenti.
  static Future<bool> reauthenticateUser({
    required String email,
    required String currentPassword,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint("Nessun utente loggato per la ri-autenticazione.");
      return false;
    }

    try {
      // 1. Crea le credenziali con l'email e la password corrente
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      // 2. Chiedi a Firebase la Re-Autenticazione
      await user.reauthenticateWithCredential(credential);
      debugPrint("Ri-autenticazione avvenuta con successo.");
      return true;
      
    } on FirebaseAuthException catch (e) {
      debugPrint("Errore di ri-autenticazione (FirebaseAuthException): ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Errore generico di ri-autenticazione: $e");
      return false;
    }
  }

  /// Esempio di utilizzo: Eliminazione dell'account in modo paranoico
  static Future<void> deleteUserAccountParanoid({
    required String email,
    required String currentPassword,
  }) async {
    bool isAuthenticated = await reauthenticateUser(
      email: email, 
      currentPassword: currentPassword,
    );

    if (isAuthenticated) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        debugPrint("Account eliminato con successo, operazione autorizzata.");
      } catch (e) {
        debugPrint("Errore durante l'eliminazione dell'account: $e");
        rethrow;
      }
    } else {
      throw Exception("Ri-autenticazione fallita. Operazione annullata.");
    }
  }
}
