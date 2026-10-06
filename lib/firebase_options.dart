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
    apiKey: 'AIzaSyCTkujkrHW-nroG_xLUmUyn3_WBWs3cRWA',
    appId: '1:930594315010:web:760f8713ef4bf3ee4d401b',
    messagingSenderId: '930594315010',
    projectId: 'cajachica-conci',
    authDomain: 'cajachica-conci.firebaseapp.com',
    storageBucket: 'cajachica-conci.firebasestorage.app',
    measurementId: 'G-52WFF8RK4B',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCoXaHabxUcGycBHfoyeGXQwjD6ojj5cW0',
    appId: '1:930594315010:android:fd1051f6fc681c1d4d401b',
    messagingSenderId: '930594315010',
    projectId: 'cajachica-conci',
    storageBucket: 'cajachica-conci.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCoXaHabxUcGycBHfoyeGXQwjD6ojj5cW0',
    appId: '1:930594315010:android:fd1051f6fc681c1d4d401b',
    messagingSenderId: '930594315010',
    projectId: 'cajachica-conci',
    storageBucket: 'cajachica-conci.firebasestorage.app',
    iosBundleId: 'com.example.pettyCashApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCoXaHabxUcGycBHfoyeGXQwjD6ojj5cW0',
    appId: '1:930594315010:android:fd1051f6fc681c1d4d401b',
    messagingSenderId: '930594315010',
    projectId: 'cajachica-conci',
    storageBucket: 'cajachica-conci.firebasestorage.app',
    iosBundleId: 'com.example.pettyCashApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCTkujkrHW-nroG_xLUmUyn3_WBWs3cRWA',
    appId: '1:930594315010:web:760f8713ef4bf3ee4d401b',
    messagingSenderId: '930594315010',
    projectId: 'cajachica-conci',
    authDomain: 'cajachica-conci.firebaseapp.com',
    storageBucket: 'cajachica-conci.firebasestorage.app',
    measurementId: 'G-52WFF8RK4B',
  );
}
