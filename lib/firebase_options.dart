import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web desteklenmiyor.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Bu platform desteklenmiyor.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcJyQBP8E2DDMx5i199OGEWe4BGHLiBj0',
    appId: '1:1000304765370:android:b84ff2118219931cd3d583',
    messagingSenderId: '1000304765370',
    projectId: 'aerotest-skyfight',
    storageBucket: 'aerotest-skyfight.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBQ2sGQoXp2l6TP_j0DuZ6Zi8cCsjO0H6M',
    appId: '1:1000304765370:ios:dce8d1fe3a8a49a6d3d583',
    messagingSenderId: '1000304765370',
    projectId: 'aerotest-skyfight',
    storageBucket: 'aerotest-skyfight.firebasestorage.app',
    iosBundleId: 'com.aerotest.app',
  );
}
