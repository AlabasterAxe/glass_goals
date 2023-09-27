import 'dart:developer';

import 'package:flutter/material.dart'
    show
        Colors,
        Dialog,
        IconButton,
        Icons,
        TextButton,
        ToggleButtons,
        Tooltip,
        showDatePicker,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        activeGoalExpiringSoonestComparator,
        getGoalStatus,
        getGoalsMatchingPredicate,
        getGoalsRequiringAttention;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'goal_list.dart' show GoalListWidget;
import 'goal_tree.dart' show GoalTreeWidget;

class DatePickerDialog extends StatefulWidget {
  final Widget title;
  const DatePickerDialog({
    super.key,
    required this.title,
  });

  @override
  State<DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<DatePickerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Column(
            children: [
              widget.title,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Forever')),
                  IconButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          locale: const Locale('en', 'GB'),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop(date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today))
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverToolbarWidget extends StatelessWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  final Function() onArchive;
  final Function() onDone;
  final Function(DateTime? endDate) onSnooze;
  final Function() onClearSelection;
  final Function(DateTime? endDate) onActive;
  const HoverToolbarWidget({
    super.key,
    required this.onMerge,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onSnooze,
    required this.onActive,
    required this.onClearSelection,
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
            Tooltip(
              message: 'Merge',
              child: IconButton(
                icon: const Icon(Icons.merge),
                onPressed: onMerge,
              ),
            ),
            Tooltip(
              message: 'Unarchive',
              child: IconButton(
                icon: const Icon(Icons.unarchive),
                onPressed: onUnarchive,
              ),
            ),
            Tooltip(
              message: 'Archive',
              child: IconButton(
                icon: const Icon(Icons.archive),
                onPressed: onArchive,
              ),
            ),
            Tooltip(
              message: 'Activate',
              child: IconButton(
                icon: const Icon(Icons.directions_run),
                onPressed: () async {
                  final DateTime? date = await showDialog(
                    context: context,
                    builder: (context) =>
                        const DatePickerDialog(title: Text('Active Until?')),
                  );
                  onActive(date);
                },
              ),
            ),
            Tooltip(
              message: 'Snooze',
              child: IconButton(
                icon: const Icon(Icons.snooze),
                onPressed: () async {
                  final DateTime? date = await showDialog(
                    context: context,
                    builder: (context) =>
                        const DatePickerDialog(title: Text('Snooze Until?')),
                  );
                  onSnooze(date);
                },
              ),
            ),
            Tooltip(
              message: 'Mark Done',
              child: IconButton(
                icon: const Icon(Icons.done),
                onPressed: onDone,
              ),
            ),
            Tooltip(
              message: 'Clear Selection',
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClearSelection,
              ),
            ),
          ],
        ));
  }
}

class GoalViewer extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewer({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewer> createState() => _GoalViewerState();
}

enum GoalView { tree, list, to_review }

class _GoalViewerState extends ConsumerState<GoalViewer> {
  final List<GoalView> _displayModeOptions = <GoalView>[
    GoalView.tree,
    GoalView.list,
    GoalView.to_review
  ];
  GoalView _selectedDisplayMode = GoalView.tree;

  String? focusedGoalId;
  Future<void>? openBoxFuture;
  bool isInitted = false;

  onSelected(String goalId) {
    setState(() {
      ref.read(selectedGoalsProvider.notifier).toggle(goalId);
      Hive.box('goals_web.ui')
          .put('selectedGoals', ref.read(selectedGoalsProvider).toList());
    });
  }

  onSwitchMode(GoalView mode) {
    setState(() {
      _selectedDisplayMode = mode;
      Hive.box('goals_web.ui')
          .put('goalViewerDisplayMode', _selectedDisplayMode?.name);
    });
  }

  onExpanded(String goalId, {bool? expanded}) {
    setState(() {
      setState(() {
        ref.read(expandedGoalsProvider.notifier).toggle(goalId);
        Hive.box('goals_web.ui')
            .put('expandedGoals', ref.read(expandedGoalsProvider).toList());
      });
    });
  }

  onFocused(String? goalId) {
    setState(() {
      focusedGoalId = goalId;
      Hive.box('goals_web.ui').put('focusedGoal', focusedGoalId);
    });
  }

  onMerge() {
    final goalIds = ref.read(selectedGoalsProvider);
    final winningGoalId = goalIds.first;
    final syncClient = AppContext.of(context).syncClient;
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in goalIds) {
      if (goalId == winningGoalId) {
        continue;
      }

      goalDeltas.add(GoalDelta(
          id: goalId,
          statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.archived,
          )));
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
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onUnarchive() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in ref.read(selectedGoalsProvider)) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.archived,
            endTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onArchive() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in ref.read(selectedGoalsProvider)) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.archived,
            startTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onDone() {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in ref.read(selectedGoalsProvider)) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
            creationTime: DateTime.now(),
            status: GoalStatus.done,
            startTime: DateTime.now()),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onSnooze(DateTime? endDate) {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in ref.read(selectedGoalsProvider)) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
          creationTime: DateTime.now(),
          status: GoalStatus.pending,
          startTime: DateTime.now(),
          endTime: endDate ?? DateTime.now().add(const Duration(days: 7)),
        ),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onClearSelection() {
    setState(() {
      ref.read(selectedGoalsProvider.notifier).clear();
    });
  }

  onActive(DateTime? endDate) {
    final List<GoalDelta> goalDeltas = [];
    for (final String goalId in ref.read(selectedGoalsProvider)) {
      goalDeltas.add(GoalDelta(
        id: goalId,
        statusLogEntry: StatusLogEntry(
          creationTime: DateTime.now(),
          status: GoalStatus.active,
          startTime: DateTime.now(),
          endTime: endDate,
        ),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!isInitted) {
      setState(() {
        openBoxFuture = Hive.openBox('goals_web.ui').then((box) {
          ref.read(selectedGoalsProvider.notifier).addAll(
              (box.get('selectedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>());
          ref.read(expandedGoalsProvider.notifier).addAll(
              (box.get('expandedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>());

          final modeString = box.get('goalViewerDisplayMode',
              defaultValue: GoalView.tree.name);
          _selectedDisplayMode = GoalView.values.byName(modeString);
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

  int _toReviewComparator(Goal goal1, Goal goal2) {
    final goal1Status = getGoalStatus(WorldContext.now(), goal1)?.status;
    final goal2Status = getGoalStatus(WorldContext.now(), goal2)?.status;
    final cmptor = activeGoalExpiringSoonestComparator(WorldContext.now());
    if (goal1Status == goal2Status) {
      if (goal1Status == GoalStatus.active) {
        return cmptor(goal1, goal2);
      }
      return goal1.text.compareTo(goal2.text);
    } else if (goal1Status == GoalStatus.active && goal2Status == null) {
      return 1;
    } else if (goal2Status == GoalStatus.active && goal1Status == null) {
      return -1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
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
                        case GoalView.list:
                          final goalIds =
                              (widget.goalMap.values.toList(growable: false)
                                    ..sort((a, b) => a.text
                                        .toLowerCase()
                                        .compareTo(b.text.toLowerCase())))
                                  .map((e) => e.id)
                                  .toList();
                          return GoalListWidget(
                            goalMap: widget.goalMap,
                            goalIds: goalIds,
                            onSelected: onSelected,
                            onExpanded: onExpanded,
                            depthLimit: 1,
                          );
                        case GoalView.to_review:
                          final goalsRequiringAttention =
                              getGoalsRequiringAttention(
                                  WorldContext.now(), widget.goalMap);
                          final goalIds = (goalsRequiringAttention.values
                                  .toList(growable: false)
                                ..sort(_toReviewComparator))
                              .map((e) => e.id)
                              .toList();

                          return GoalListWidget(
                            goalMap: widget.goalMap,
                            goalIds: goalIds,
                            onSelected: onSelected,
                            onExpanded: onExpanded,
                            depthLimit: 1,
                          );
                        default:
                          final pendingGoalMap = getGoalsMatchingPredicate(
                              worldContext,
                              widget.goalMap,
                              (goal) =>
                                  getGoalStatus(worldContext, goal)?.status !=
                                      GoalStatus.archived &&
                                  getGoalStatus(worldContext, goal)?.status !=
                                      GoalStatus.done);
                          final rootGoalIds = pendingGoalMap.values
                              .where((goal) => goal.parentId == null)
                              .map((e) => e.id)
                              .toList();
                          return GoalListWidget(
                              goalMap: pendingGoalMap,
                              goalIds: rootGoalIds,
                              onSelected: onSelected,
                              onExpanded: onExpanded);
                      }
                    })),
          ),
          ToggleButtons(
            direction: Axis.horizontal,
            onPressed: (index) {
              setState(() {
                onSwitchMode(_displayModeOptions[index]);
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
                width: 400,
                height: 50,
                child: HoverToolbarWidget(
                  onMerge: onMerge,
                  onUnarchive: onUnarchive,
                  onArchive: onArchive,
                  onDone: onDone,
                  onSnooze: onSnooze,
                  onActive: onActive,
                  onClearSelection: onClearSelection,
                ),
              )
            : Container(),
      ],
    );
  }
}
