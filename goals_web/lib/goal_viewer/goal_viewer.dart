import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart'
    show
        AppBar,
        Colors,
        Dialog,
        Drawer,
        IconButton,
        Icons,
        ListTile,
        Scaffold,
        TextButton,
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
import 'package:multi_split_view/multi_split_view.dart';

import '../app.gr.dart';
import '../styles.dart' show multiSplitViewThemeData;
import 'goal_list.dart' show GoalListWidget;

class ViewerArgs {
  final String? focusedGoalId;

  ViewerArgs(this.focusedGoalId);
}

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

class GoalViewerPage extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewerPage({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewerPage> createState() => _GoalViewerState();
}

enum GoalView { tree, list, to_review }

class _GoalViewerState extends ConsumerState<GoalViewerPage> with RouteAware {
  GoalView _selectedDisplayMode = GoalView.tree;

  Future<void>? openBoxFuture;
  String? prevFocusedGoalId;
  late StreamSubscription focusedGoalSubscription;
  bool isInitted = false;
  final _multiSplitViewController = MultiSplitViewController(areas: [
    Area(
      size: 250,
      minimalSize: 200,
      key: const ValueKey('viewSwitcher'),
    ),
    Area(
      weight: 0.5,
      minimalSize: 200,
      key: const ValueKey('list'),
    ),
    Area(
      weight: 0.5,
      minimalSize: 200,
      key: const ValueKey('detail'),
    )
  ]);

  void _handleFocusedGoalUpdate(String? newFocusedGoalId) {
    if (prevFocusedGoalId == newFocusedGoalId) {
      return;
    }
    print('Focused goal changed from $prevFocusedGoalId to $newFocusedGoalId');

    if (newFocusedGoalId == null) {
      context.router.pop();
    } else if (prevFocusedGoalId == null) {
      context.router.push(GoalDetail(goalId: newFocusedGoalId));
    } else {
      context.router.popAndPush(GoalDetail(goalId: newFocusedGoalId));
    }
  }

  @override
  initState() {
    super.initState();
    focusedGoalSubscription =
        focusedGoalSubject.asBroadcastStream().listen(_handleFocusedGoalUpdate);
  }

  @override
  dispose() {
    focusedGoalSubscription.cancel();
    super.dispose();
  }

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
          .put('goalViewerDisplayMode', _selectedDisplayMode.name);
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
      focusedGoalSubject.add(goalId);
      Hive.box('goals_web.ui').put('focusedGoal', goalId);
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
          logEntry: StatusLogEntry(
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
        logEntry: StatusLogEntry(
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
        logEntry: StatusLogEntry(
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
        logEntry: StatusLogEntry(
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
        logEntry: StatusLogEntry(
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
        logEntry: StatusLogEntry(
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

  int _toReviewComparator(Goal goal1, Goal goal2) {
    final goal1Status = getGoalStatus(WorldContext.now(), goal1).status;
    final goal2Status = getGoalStatus(WorldContext.now(), goal2).status;
    final cmptor = activeGoalExpiringSoonestComparator(WorldContext.now());
    if (goal1Status == goal2Status) {
      if (goal1Status == GoalStatus.active) {
        return cmptor(goal1, goal2);
      }
      final goal1Parent = widget.goalMap[goal1.parentId];
      final goal2Parent = widget.goalMap[goal2.parentId];
      if (goal1Parent != null && goal2Parent != null) {
        return goal1Parent.text.compareTo(goal2Parent.text);
      } else if (goal1Parent != null && goal2Parent == null) {
        return goal1Parent.text.compareTo(goal2.text);
      } else if (goal2Parent != null && goal1Parent == null) {
        return goal1.text.compareTo(goal2Parent.text);
      }
      return goal1.text.compareTo(goal2.text);
    } else if (goal1Status == GoalStatus.active && goal2Status == null) {
      return 1;
    } else if (goal2Status == GoalStatus.active && goal1Status == null) {
      return -1;
    }
    return 0;
  }

  _viewSwitcher(bool closeDrawer) => ListView(
        key: const ValueKey('viewSwitcher'),
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            title: const Text('Tree'),
            selected: _selectedDisplayMode == GoalView.tree,
            onTap: () {
              // Update the state of the app
              onSwitchMode(GoalView.tree);
              if (closeDrawer) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('List'),
            selected: _selectedDisplayMode == GoalView.list,
            onTap: () {
              // Update the state of the app
              onSwitchMode(GoalView.list);
              if (closeDrawer) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('To Review'),
            selected: _selectedDisplayMode == GoalView.to_review,
            onTap: () {
              // Update the state of the app
              onSwitchMode(GoalView.to_review);
              if (closeDrawer) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);

    return StreamBuilder<String?>(
        stream: focusedGoalSubject,
        builder: (context, focusedGoalSnapshot) {
          final children = <Widget>[];

          final isNarrow = MediaQuery.of(context).size.width < 600;
          if (!isNarrow) {
            children.add(_viewSwitcher(false));
          }
          final focusedGoalId = focusedGoalSnapshot.data;

          if (focusedGoalId == null || !isNarrow) {
            children.add(_listView());
          }

          if (focusedGoalId != null) {
            children.add(_detailView());
          }
          return Scaffold(
            appBar: AppBar(
              title: const Text('Glass Goals'),
            ),
            drawer: isNarrow
                ? Drawer(
                    child: _viewSwitcher(true),
                  )
                : null,
            body: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                MultiSplitViewTheme(
                    data: multiSplitViewThemeData,
                    child: MultiSplitView(
                      controller: _multiSplitViewController,
                      children: children,
                    )),
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
            ),
          );
        });
  }

  Widget _listView() {
    return SingleChildScrollView(
        key: const ValueKey('list'),
        child: FutureBuilder<void>(
            future: openBoxFuture,
            builder: (context, snapshot) {
              final worldContext = WorldContext.now();
              if (snapshot.connectionState != ConnectionState.done) {
                return const Text('Loading...');
              }
              switch (_selectedDisplayMode) {
                case GoalView.list:
                  final goalIds = (widget.goalMap.values.toList(growable: false)
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
                    onFocused: onFocused,
                    depthLimit: 1,
                  );
                case GoalView.to_review:
                  final goalsRequiringAttention = getGoalsRequiringAttention(
                      WorldContext.now(), widget.goalMap);
                  final goalIds =
                      (goalsRequiringAttention.values.toList(growable: false)
                            ..sort(_toReviewComparator))
                          .map((e) => e.id)
                          .toList();

                  return GoalListWidget(
                    goalMap: widget.goalMap,
                    goalIds: goalIds,
                    onSelected: onSelected,
                    onExpanded: onExpanded,
                    onFocused: onFocused,
                    depthLimit: 1,
                  );
                default:
                  final pendingGoalMap = getGoalsMatchingPredicate(
                      worldContext,
                      widget.goalMap,
                      (goal) =>
                          getGoalStatus(worldContext, goal).status !=
                              GoalStatus.archived &&
                          getGoalStatus(worldContext, goal).status !=
                              GoalStatus.done);
                  final rootGoalIds = pendingGoalMap.values
                      .where((goal) => goal.parentId == null)
                      .map((e) => e.id)
                      .toList();
                  return GoalListWidget(
                    goalMap: pendingGoalMap,
                    goalIds: rootGoalIds,
                    onSelected: onSelected,
                    onExpanded: onExpanded,
                    onFocused: onFocused,
                    showAddGoal: true,
                  );
              }
            }));
  }

  Widget _detailView() {
    return const AutoRouter(key: ValueKey('detail'));
  }
}
