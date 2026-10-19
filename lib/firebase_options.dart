// File generated for CONCI project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmsE6W6j1rMJiOcIU675wkIJK9L5mMApU',
    appId: '1:272109087873:web:64e14d52e4747023993180',
    messagingSenderId: '272109087873',
    projectId: 'conci-cajachica',
    authDomain: 'conci-cajachica.firebaseapp.com',
    storageBucket: 'conci-cajachica.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD44Wh8CCO2wKlLBs7-_-1LP4MQof7ViSA',
    appId: '1:272109087873:android:51ed72a58ecf4e18993180',
    messagingSenderId: '272109087873',
    projectId: 'conci-cajachica',
    storageBucket: 'conci-cajachica.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD44Wh8CCO2wKlLBs7-_-1LP4MQof7ViSA',
    appId: '1:272109087873:android:51ed72a58ecf4e18993180',
    messagingSenderId: '272109087873',
    projectId: 'conci-cajachica',
    storageBucket: 'conci-cajachica.firebasestorage.app',
    iosBundleId: 'com.example.pettyCashApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD44Wh8CCO2wKlLBs7-_-1LP4MQof7ViSA',
    appId: '1:272109087873:android:51ed72a58ecf4e18993180',
    messagingSenderId: '272109087873',
    projectId: 'conci-cajachica',
    storageBucket: 'conci-cajachica.firebasestorage.app',
    iosBundleId: 'com.example.pettyCashApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCmsE6W6j1rMJiOcIU675wkIJK9L5mMApU',
    appId: '1:272109087873:web:64e14d52e4747023993180',
    messagingSenderId: '272109087873',
    projectId: 'conci-cajachica',
    authDomain: 'conci-cajachica.firebaseapp.com',
    storageBucket: 'conci-cajachica.firebasestorage.app',
  );
}
