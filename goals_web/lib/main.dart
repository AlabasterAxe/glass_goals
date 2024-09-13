import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show EmailAuthProvider, FirebaseUIAuth;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    show GoogleProvider;
import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/firebase_options.dart';
import 'package:goals_web/fix_enter_issue.dart';
import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fixEnterStuckIssue();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  FirebaseUIAuth.configureProviders([
    GoogleProvider(
        clientId:
            '114797465949-keupvd032s4to34t1bkftge1baoguld5.apps.googleusercontent.com'),
    EmailAuthProvider(),
  ]);

  usePathUrlStrategy();
  runApp(ProviderScope(
      child: WebGoals(persistenceService: FirestorePersistenceService())));
}
