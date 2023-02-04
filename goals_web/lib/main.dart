import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'app_context.dart' show AppContext;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show SyncClient, rootGoal, GoogleSheetsPersistenceService;

import 'goal_viewer/goal_viewer.dart';

void main() {
  runApp(const WebGoals());
}

class WebGoals extends StatefulWidget {
  const WebGoals({super.key});

  @override
  State<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends State<WebGoals>
    with SingleTickerProviderStateMixin {
  SyncClient syncClient =
      SyncClient(persistenceService: GoogleSheetsPersistenceService());

  Future<void> appInit() async {
    await Hive.initFlutter();
    await syncClient.init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: appInit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
                home: Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator()))));
          }
          return AppContext(
              syncClient: syncClient,
              child: MaterialApp(
                title: 'Glass Goals',
                theme: ThemeData(
                  primaryColor: Colors.black,
                ),
                home: const GoalsHome(),
              ));
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
            return GoalViewer(
                goalMap: snapshot.requireData, rootGoalId: rootGoal.id);
          }),
    );
  }
}
