import 'package:flutter/material.dart'
    show Colors, IconButton, Icons, ToggleButtons;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart' show GoalDelta, archiveGoal, rootGoal;
import 'package:goals_web/app_context.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'goal_list.dart' show GoalListWidget;
import 'goal_tree.dart' show GoalTreeWidget;

class HoverToolbarWidget extends StatelessWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  const HoverToolbarWidget({
    super.key,
    required this.onMerge,
    required this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.merge),
              onPressed: onMerge,
            ),
            IconButton(
              icon: const Icon(Icons.unarchive),
              onPressed: onUnarchive,
            ),
          ],
        ));
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
  final Set<String> expandedGoals = {};
  Future<void>? openBoxFuture;
  bool isInitted = false;

  onSelected(String goalId) {
    setState(() {
      if (selectedGoals.contains(goalId)) {
        selectedGoals.remove(goalId);
      } else {
        selectedGoals.add(goalId);
      }
      Hive.box('goals_web.ui').put('selectedGoals', selectedGoals.toList());
    });
  }

  onExpanded(String goalId) {
    setState(() {
      if (expandedGoals.contains(goalId)) {
        expandedGoals.remove(goalId);
      } else {
        expandedGoals.add(goalId);
      }
      Hive.box('goals_web.ui').put('expandedGoals', expandedGoals.toList());
    });
  }

  onMerge() {
    final winningGoalId = selectedGoals.first;
    final syncClient = AppContext.of(context).syncClient;
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in selectedGoals) {
      if (goalId == winningGoalId) {
        continue;
      }

      goalDeltas.add(GoalDelta(
        id: goalId,
        parentId: archiveGoal.id,
      ));
      final goal = widget.goalMap[goalId];
      if (goal != null) {
        for (final Goal childGoal in goal.subGoals) {
          goalDeltas.add(GoalDelta(
            id: childGoal.id,
            parentId: winningGoalId,
          ));
        }
      }
    }

    syncClient.modifyGoals(goalDeltas);
    selectedGoals.clear();
  }

  onUnarchive() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in selectedGoals) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        parentId: rootGoal.id,
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoals.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!isInitted) {
      setState(() {
        openBoxFuture = Hive.openBox('goals_web.ui').then((box) {
          selectedGoals.addAll(
              (box.get('selectedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>());
          expandedGoals.addAll(
              (box.get('expandedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>());
        });
        isInitted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // my name is matt
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: SingleChildScrollView(
                child: FutureBuilder<void>(
                    future: openBoxFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Text('Loading...');
                      }
                      return _displayMode[0]
                          ? GoalTreeWidget(
                              goalMap: widget.goalMap,
                              rootGoalId: widget.rootGoalId,
                              selectedGoals: selectedGoals,
                              onSelected: onSelected,
                              expandedGoals: expandedGoals,
                              onExpanded: onExpanded,
                            )
                          : GoalListWidget(
                              goalMap: widget.goalMap,
                              selectedGoals: selectedGoals,
                              onSelected: onSelected,
                              expandedGoals: expandedGoals,
                              onExpanded: onExpanded,
                            );
                    })),
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
        ]),
        selectedGoals.isNotEmpty
            ? Positioned(
                top: 50,
                width: 200,
                height: 50,
                child: HoverToolbarWidget(
                    onMerge: onMerge, onUnarchive: onUnarchive),
              )
            : Container(),
      ],
    );
  }
}
