import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show AuthStateChangeAction, FirebaseUIAuth, SignInScreen, SignedIn;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    show GoogleProvider;

import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:goals_core/sync.dart'
    show FirestorePersistenceService, GoogleSheetsPersistenceService;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  FirebaseUIAuth.configureProviders([
    GoogleProvider(
        clientId:
            '114797465949-keupvd032s4to34t1bkftge1baoguld5.apps.googleusercontent.com'),
  ]);

  runApp(Cloner());
}

class Cloner extends StatefulWidget {
  const Cloner({super.key});

  @override
  State<Cloner> createState() => _ClonerState();
}

class _ClonerState extends State<Cloner> {
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
      '/home': (context) => const GoalsHome(),
    });
  }
}

class GoalsHome extends StatefulWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  State<GoalsHome> createState() => _GoalsHomeState();
}

enum _SyncState { notStarted, inProgress, complete, error }

class _GoalsHomeState extends State<GoalsHome> {
  _SyncState _syncState = _SyncState.notStarted;
  List<String> log = [];

  @override
  Widget build(BuildContext context) {
    switch (_syncState) {
      case _SyncState.notStarted:
        return MaterialButton(
            onPressed: () async {
              setState(() {
                _syncState = _SyncState.inProgress;
                log = ["Constructing Persistence Services"];
              });
              final source = GoogleSheetsPersistenceService();
              final dest = FirestorePersistenceService();
              try {
                setState(() {
                  log.add("Requesting Existing Ops");
                });
                final [sourceResp, existingDestResp] =
                    await Future.wait([source.load(), dest.load()]);
                setState(() {
                  log.add("Found ${sourceResp.ops.length} ops in source.");
                  log.add(
                      "Found ${existingDestResp.ops.length} ops in destination.");
                  log.add("Filtering existing ops from source ops.");
                });
                // get ops from source that don't exist in dest:
                final ops = sourceResp.ops
                    .where((op) => !existingDestResp.ops.contains(op))
                    .toList();
                setState(() {
                  log.add("Got ${ops.length} ops to clone.");
                  log.add("Cloning...");
                });
                await dest.save(ops);
                setState(() {
                  log.add("Done!");
                });
              } catch (e) {
                setState(() {
                  _syncState = _SyncState.error;
                });
                return;
              }

              setState(() {
                _syncState = _SyncState.complete;
              });
            },
            child: const Text('Clone'));
      case _SyncState.inProgress:
        return Center(
            child: Column(
          children: [
            const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator()),
            Text(log.join('\n')),
          ],
        ));
      case _SyncState.complete:
        return const Text('Complete');
      case _SyncState.error:
        return const Text('Error');
    }
  }
}
