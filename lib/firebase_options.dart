import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Sostituisci "INSERISCI_API_KEY_QUI" e gli App ID con i valori reali
  // dalla tua Firebase Console -> Impostazioni Progetto -> Generali
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBjry_qqw3N2eKOpmbroMtsj5I2iU5g8a4',
    appId: '1:468446089858:web:0815544662d18b12201a9b',
    messagingSenderId: '468446089858',
    projectId: 'guess-me-bfd58',
    authDomain: 'guess-me-bfd58.firebaseapp.com',
    databaseURL: 'https://guess-me-bfd58-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'guess-me-bfd58.firebasestorage.app',
    measurementId: 'G-DUMMY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjry_qqw3N2eKOpmbroMtsj5I2iU5g8a4',
    appId: '1:1234567890:android:dummy1234',
    messagingSenderId: '468446089858',
    projectId: 'guess-me-bfd58',
    databaseURL: 'https://guess-me-bfd58-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'guess-me-bfd58.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBjry_qqw3N2eKOpmbroMtsj5I2iU5g8a4',
    appId: '1:1234567890:ios:dummy1234',
    messagingSenderId: '468446089858',
    projectId: 'guess-me-bfd58',
    databaseURL: 'https://guess-me-bfd58-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'guess-me-bfd58.firebasestorage.app',
    iosBundleId: 'com.antigravity.guess_me',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBjry_qqw3N2eKOpmbroMtsj5I2iU5g8a4',
    appId: '1:1234567890:ios:dummy1234',
    messagingSenderId: '468446089858',
    projectId: 'guess-me-bfd58',
    databaseURL: 'https://guess-me-bfd58-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'guess-me-bfd58.firebasestorage.app',
    iosBundleId: 'com.antigravity.guess_me',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBjry_qqw3N2eKOpmbroMtsj5I2iU5g8a4',
    appId: '1:468446089858:web:0815544662d18b12201a9b',
    messagingSenderId: '468446089858',
    projectId: 'guess-me-bfd58',
    authDomain: 'guess-me-bfd58.firebaseapp.com',
    databaseURL: 'https://guess-me-bfd58-default-rtdb.europe-west1.firebasedatabase.app',
    measurementId: 'G-DUMMY',
  );
}
