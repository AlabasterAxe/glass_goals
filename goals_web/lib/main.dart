import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goals_web/goal_list.dart';

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

class GoalViewer extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  const GoalViewer(
      {super.key, required this.goalMap, required this.rootGoalId});

  @override
  State<GoalViewer> createState() => _GoalViewerState();
}

class _GoalViewerState extends State<GoalViewer> {
  final List<bool> _displayMode = <bool>[true, false];
  final Set<String> selectedGoals = {};

  onSelected(String goalId) {
    setState(() {
      if (selectedGoals.contains(goalId)) {
        selectedGoals.remove(goalId);
      } else {
        selectedGoals.add(goalId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: SingleChildScrollView(
          child: _displayMode[0]
              ? GoalTreeWidget(
                  goalMap: widget.goalMap,
                  rootGoalId: widget.rootGoalId,
                  selectedGoals: selectedGoals,
                  onSelected: onSelected,
                )
              : GoalListWidget(
                  goalMap: widget.goalMap,
                  selectedGoals: selectedGoals,
                  onSelected: onSelected,
                ),
        ),
      ),
      ToggleButtons(
        direction: Axis.horizontal,
        onPressed: (index) {
          setState(() {
            for (int i = 0; i < _displayMode.length; i++) {
              _displayMode[i] = i == index;
            }
          });
        },
        isSelected: _displayMode,
        children: const [
          Text('Tree'),
          Text('List'),
        ],
      ),
    ]);
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
            return SingleChildScrollView(
              child: GoalViewer(
                  goalMap: snapshot.requireData, rootGoalId: rootGoal.id),
            );
          }),
    );
  }
}
