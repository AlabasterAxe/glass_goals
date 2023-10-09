import 'package:firebase_core/firebase_core.dart' show Firebase;
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
  await Hive.initFlutter();

  usePathUrlStrategy();
  runApp(ProviderScope(
      child: WebGoals(
          persistenceService: FirestorePersistenceService(readonly: true))));
}
