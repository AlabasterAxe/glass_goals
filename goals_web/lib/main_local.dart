import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show EmailAuthProvider, FirebaseUIAuth;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    show GoogleProvider;
import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart' show FirestorePersistenceService;
import 'package:goals_web/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

  FirebaseUIAuth.configureProviders([
    GoogleProvider(
        clientId:
            '114797465949-keupvd032s4to34t1bkftge1baoguld5.apps.googleusercontent.com'),
    EmailAuthProvider(),
  ]);
  await Hive.initFlutter();

  usePathUrlStrategy();
  runApp(ProviderScope(
      child: WebGoals(
          debug: true, persistenceService: FirestorePersistenceService())));
}
