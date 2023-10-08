import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart' show InMemoryPersistenceService;
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
          shouldAuthenticate: false,
          persistenceService: InMemoryPersistenceService(ops: [
            {
              'hlcTimestamp':
                  '001674571071065:00001:db86cca1-fa15-4f6d-b37e-0d19bfb8f95a',
              'version': 2,
              'delta': {'id': 'root', 'text': 'Test Root'}
            },
            {
              'hlcTimestamp':
                  '001674571071065:00001:db86cca1-fa15-4f6d-b37e-0d19bfb8f95a',
              'version': 2,
              'delta': {'id': 'child', 'text': 'Test Child', 'parentId': 'root'}
            }
          ]))));
}
