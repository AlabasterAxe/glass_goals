import 'package:flutter/material.dart'
    show Colors, IconButton, Icons, ToggleButtons;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getGoalStatus,
        getGoalsMatchingPredicate,
        getGoalsRequiringAttention;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry, archiveGoal, rootGoal;
import 'package:goals_web/app_context.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'goal_list.dart' show GoalListWidget;
import 'goal_tree.dart' show GoalTreeWidget;

class HoverToolbarWidget extends StatelessWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  final Function() onArchive;
  final Function() onDone;
  final Function() onPending;
  const HoverToolbarWidget({
    super.key,
    required this.onMerge,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onPending,
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
            IconButton(
              icon: const Icon(Icons.archive),
              onPressed: onArchive,
            ),
            IconButton(
              icon: const Icon(Icons.done),
              onPressed: onDone,
            ),
            IconButton(
              icon: const Icon(Icons.access_time),
              onPressed: onPending,
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

enum GoalView { tree, list, to_review }

class _GoalViewerState extends State<GoalViewer> {
  final List<GoalView> _displayModeOptions = <GoalView>[
    GoalView.tree,
    GoalView.list,
    GoalView.to_review
  ];
  GoalView _selectedDisplayMode = GoalView.tree;

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
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.archived,
            endTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoals.clear();
  }

  onArchive() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in selectedGoals) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.archived,
            startTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoals.clear();
  }

  onDone() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in selectedGoals) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.done,
            startTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoals.clear();
  }

  onPending() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in selectedGoals) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
          creationTime: DateTime.now(),
          status: GoalStatus.pending,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(days: 7)),
        ),
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

  List<bool> _getOneHot() {
    final List<bool> oneHot =
        List<bool>.filled(_displayModeOptions.length, false);
    oneHot[_displayModeOptions.indexOf(_selectedDisplayMode)] = true;
    return oneHot;
  }

  @override
  Widget build(BuildContext context) {
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
                      final worldContext = WorldContext.now();
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Text('Loading...');
                      }
                      switch (_selectedDisplayMode) {
                        case GoalView.tree:
                          return GoalTreeWidget(
                            goalMap: getGoalsMatchingPredicate(
                                worldContext,
                                widget.goalMap,
                                (goal) =>
                                    getGoalStatus(worldContext, goal)?.status !=
                                        GoalStatus.archived &&
                                    getGoalStatus(worldContext, goal)?.status !=
                                        GoalStatus.done),
                            rootGoalId: widget.rootGoalId,
                            selectedGoals: selectedGoals,
                            onSelected: onSelected,
                            expandedGoals: expandedGoals,
                            onExpanded: onExpanded,
                          );
                        case GoalView.list:
                          return GoalListWidget(
                            goalMap: widget.goalMap,
                            selectedGoals: selectedGoals,
                            onSelected: onSelected,
                            expandedGoals: expandedGoals,
                            onExpanded: onExpanded,
                          );
                        case GoalView.to_review:
                          return GoalListWidget(
                            goalMap: getGoalsRequiringAttention(
                                WorldContext.now(), widget.goalMap),
                            selectedGoals: selectedGoals,
                            onSelected: onSelected,
                            expandedGoals: expandedGoals,
                            onExpanded: onExpanded,
                          );
                      }
                    })),
          ),
          ToggleButtons(
            direction: Axis.horizontal,
            onPressed: (index) {
              setState(() {
                _selectedDisplayMode = _displayModeOptions[index];
              });
            },
            isSelected: _getOneHot(),
            children: const [
              Text('Tree'),
              Text('List'),
              Text('To Review'),
            ],
          ),
        ]),
        selectedGoals.isNotEmpty
            ? Positioned(
                top: 50,
                width: 200,
                height: 50,
                child: HoverToolbarWidget(
                  onMerge: onMerge,
                  onUnarchive: onUnarchive,
                  onArchive: onArchive,
                  onDone: onDone,
                  onPending: onPending,
                ),
              )
            : Container(),
      ],
    );
  }
}
