// TEMPLATE FILE -- DO NOT USE AS-IS.
//
// Run the FlutterFire CLI in your project root to generate the real file:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command creates lib/firebase_options.dart with your actual project's
// API keys/app IDs. Either replace the contents of this file with the
// generated output, or update the import in main.dart to point at
// firebase_options.dart instead.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Run `flutterfire configure` to generate real web options.',
      );
    }
    switch (Platform.operatingSystem) {
      case 'android':
        return const FirebaseOptions(
          apiKey: 'REPLACE_ME',
          appId: 'REPLACE_ME',
          messagingSenderId: 'REPLACE_ME',
          projectId: 'REPLACE_ME',
        );
      case 'ios':
        return const FirebaseOptions(
          apiKey: 'REPLACE_ME',
          appId: 'REPLACE_ME',
          messagingSenderId: 'REPLACE_ME',
          projectId: 'REPLACE_ME',
          iosBundleId: 'REPLACE_ME',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run `flutterfire configure`.',
        );
    }
  }
}
