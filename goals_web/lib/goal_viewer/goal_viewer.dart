import 'dart:html';

import 'package:flutter/material.dart'
    show AppBar, Drawer, IconButton, Icons, ListTile, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getGoalStatus,
        getGoalsMatchingPredicate,
        getGoalsRequiringAttention;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/goal_detail.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../styles.dart' show multiSplitViewThemeData;
import 'goal_list.dart' show GoalListWidget;
import 'hover_actions.dart';

class GoalViewer extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewer({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewer> createState() => _GoalViewerState();
}

enum GoalView { tree, list, to_review }

class _GoalViewerState extends ConsumerState<GoalViewer> {
  GoalView _selectedDisplayMode = GoalView.tree;

  Future<void>? openBoxFuture;
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
      ref.read(focusedGoalProvider.notifier).set(goalId);
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

  _handlePopState(_) {
    final focusedGoalId = ref.read(focusedGoalProvider);
    if (_parseUrlGoalId() != focusedGoalId) {
      ref.read(focusedGoalProvider.notifier).set(_parseUrlGoalId());
    }
  }

  String? _parseUrlGoalId() {
    final parts = window.location.href.split('/');
    if (parts.length >= 3 && parts[parts.length - 2] == 'goal') {
      return parts[parts.length - 1];
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!isInitted) {
      ref.read(focusedGoalProvider.notifier).set(_parseUrlGoalId());
      window.addEventListener('popstate', _handlePopState);
      setState(() {
        openBoxFuture = Hive.openBox('goals_web.ui').then((box) {
          if (mounted) {
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
          }
        });
        isInitted = true;
      });
    }
  }

  @override
  dispose() {
    window.removeEventListener('popstate', _handlePopState);
    super.dispose();
  }

  _handleFocusedGoalChange(prevGoalId, newGoalId) {
    if (prevGoalId == newGoalId) {
      return;
    }
    if (newGoalId == null) {
      window.history.pushState(null, 'home', '/home');
    } else if (!window.location.href.endsWith('goal/$newGoalId')) {
      window.history.pushState(null, 'home', '/home/goal/$newGoalId');
    }
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
    final focusedGoal = ref.watch(focusedGoalProvider);
    final worldContext = ref.watch(worldContextProvider);
    ref.listen(focusedGoalProvider, _handleFocusedGoalChange);

    final children = <Widget>[];

    final isNarrow = MediaQuery.of(context).size.width < 600;
    if (!isNarrow) {
      children.add(_viewSwitcher(false));
    }

    if (!isNarrow || focusedGoal == null) {
      children.add(_listView(worldContext));
    }

    if (focusedGoal != null) {
      children.add(_detailView());
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Glass Goals'),
          leading: isNarrow
              ? focusedGoal != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        ref.read(focusedGoalProvider.notifier).set(null);
                      })
                  : Builder(builder: (context) {
                      return IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          });
                    })
              : null),
      drawer: isNarrow && focusedGoal == null
          ? Drawer(
              child: _viewSwitcher(true),
            )
          : null,
      body: children.length == 1
          ? Positioned.fill(child: children[0])
          : MultiSplitViewTheme(
              data: multiSplitViewThemeData,
              child: MultiSplitView(
                controller: _multiSplitViewController,
                children: children,
              )),
    );
  }

  Widget _listView(WorldContext worldContext) {
    return SingleChildScrollView(
        key: const ValueKey('list'),
        child: FutureBuilder<void>(
            future: openBoxFuture,
            builder: (context, snapshot) {
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
                      hoverActions: HoverActionsWidget(
                          onMerge: onMerge,
                          onUnarchive: onUnarchive,
                          onArchive: onArchive,
                          onDone: onDone,
                          onSnooze: onSnooze,
                          onActive: onActive,
                          onClearSelection: onClearSelection,
                          goalMap: widget.goalMap));
                case GoalView.to_review:
                  final goalsRequiringAttention =
                      getGoalsRequiringAttention(worldContext, widget.goalMap);
                  final rootGoalIds = goalsRequiringAttention.values
                      .where((goal) =>
                          !goalsRequiringAttention.containsKey(goal.parentId))
                      .map((e) => e.id)
                      .toList();

                  return GoalListWidget(
                    goalMap: goalsRequiringAttention,
                    goalIds: rootGoalIds,
                    onSelected: onSelected,
                    onExpanded: onExpanded,
                    onFocused: onFocused,
                    hoverActions: HoverActionsWidget(
                        onMerge: onMerge,
                        onUnarchive: onUnarchive,
                        onArchive: onArchive,
                        onDone: onDone,
                        onSnooze: onSnooze,
                        onActive: onActive,
                        onClearSelection: onClearSelection,
                        goalMap: widget.goalMap),
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
                    hoverActions: HoverActionsWidget(
                        onMerge: onMerge,
                        onUnarchive: onUnarchive,
                        onArchive: onArchive,
                        onDone: onDone,
                        onSnooze: onSnooze,
                        onActive: onActive,
                        onClearSelection: onClearSelection,
                        goalMap: widget.goalMap),
                  );
              }
            }));
  }

  Widget _detailView() {
    final focusedGoalId = ref.watch(focusedGoalProvider);
    final focusedGoal = widget.goalMap[focusedGoalId];
    if (focusedGoal == null) {
      return Container();
    }

    return GoalDetail(key: const ValueKey('detail'), goal: focusedGoal);
  }
}
