import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show AuthStateChangeAction, FirebaseUIAuth, SignInScreen, SignedIn;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    show GoogleProvider;

import 'package:flutter/material.dart';
import 'package:goals_web/firebase_options.dart';

import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'app_context.dart' show AppContext;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show FirestorePersistenceService, SyncClient, rootGoal;

import 'goal_viewer/goal_viewer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  FirebaseUIAuth.configureProviders([
    GoogleProvider(
        clientId:
            '114797465949-keupvd032s4to34t1bkftge1baoguld5.apps.googleusercontent.com'),
  ]);

  runApp(const ProviderScope(child: WebGoals()));
}

class WebGoals extends StatefulWidget {
  const WebGoals({super.key});

  @override
  State<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends State<WebGoals>
    with SingleTickerProviderStateMixin {
  SyncClient syncClient =
      SyncClient(persistenceService: FirestorePersistenceService());

  Future<void> appInit() async {
    await syncClient.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(initialRoute: '/sign-in', routes: {
      '/sign-in': (context) => SignInScreen(
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                // this isn't a widget it's an action, navigate to the home route
                Navigator.pushNamed(context, '/home');
              })
            ],
          ),
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
            return AppContext(syncClient: syncClient, child: const GoalsHome());
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
