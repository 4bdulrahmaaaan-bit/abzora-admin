import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';

class FirebaseDatabaseService {
  static FirebaseDatabase get instance {
    final app = Firebase.apps.isNotEmpty ? Firebase.app() : null;
    final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (app != null && databaseUrl != null && databaseUrl.isNotEmpty) {
      return FirebaseDatabase.instanceFor(app: app, databaseURL: databaseUrl);
    }
    return FirebaseDatabase.instance;
  }
}
