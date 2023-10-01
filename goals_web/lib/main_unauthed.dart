import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show Firebase;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;
import 'package:goals_web/firebase_options.dart';
import 'styles.dart' show theme;

import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'app_context.dart' show AppContext;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show InMemoryPersistenceService, SyncClient;

import 'goal_viewer/goal_viewer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  runApp(const ProviderScope(child: WebGoals()));
}

class WebGoals extends StatefulWidget {
  const WebGoals({super.key});

  @override
  State<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends State<WebGoals>
    with SingleTickerProviderStateMixin {
  SyncClient syncClient = SyncClient(
      persistenceService: InMemoryPersistenceService(ops: [
    {
      'hlcTimestamp':
          '001674571071065:00001:db86cca1-fa15-4f6d-b37e-0d19bfb8f95a',
      'version': 2,
      'delta': {'id': 'root', 'text': 'Test Root'}
    }
  ]));

  Future<void> appInit() async {
    await syncClient.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme,
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('en', 'GB'),
        ],
        initialRoute: '/home',
        routes: {
          '/home': (context) => FutureBuilder<void>(
              future: appInit(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator()));
                }
                return AppContext(
                    syncClient: syncClient, child: const GoalsHome());
              }),
        });
  }
}

class GoalsHome extends StatelessWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, Goal>>(
          stream: AppContext.of(context).syncClient.stateSubject,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()));
            }
            return GoalViewer(goalMap: snapshot.requireData);
          }),
    );
  }
}
