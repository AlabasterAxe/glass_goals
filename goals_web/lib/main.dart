import 'dart:async';

import 'package:flutter/material.dart';

import './app_context.dart' show AppContext;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show SyncClient, rootGoal, GoogleSheetsPersistenceService;

import 'goal_tree.dart' show GoalTreeWidget;

void main() {
  runApp(const GlassGoals());
}

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key});

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals>
    with SingleTickerProviderStateMixin {
  SyncClient syncClient =
      SyncClient(persistenceService: GoogleSheetsPersistenceService());
  late AnimationController backgroundColorAnimationController =
      AnimationController(vsync: this);

  Future<void> appInit() async {
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
    return StreamBuilder<Map<String, Goal>>(
        stream: AppContext.of(context).syncClient.stateSubject,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator()));
          }
          return GoalTreeWidget(
              goalMap: snapshot.requireData, rootGoalId: rootGoal.id);
        });
  }
}
