import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated for Android on Firebase project 'cw-02-mad'.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is configured for Android in this assignment build.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7TJNJAWKySXT0yMp-eLEeteYCUI3LkRE',
    appId: '1:1098740231106:android:02dd5f67b5917ff739445b',
    messagingSenderId: '1098740231106',
    projectId: 'cw-02-mad',
    storageBucket: 'cw-02-mad.firebasestorage.app',
  );
}
