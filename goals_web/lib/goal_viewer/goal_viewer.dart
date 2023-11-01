import 'dart:html';

import 'package:flutter/material.dart'
    show
        AppBar,
        Colors,
        Drawer,
        IconButton,
        Icons,
        ListTile,
        Scaffold,
        TextButton,
        Theme,
        Tooltip;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getGoalStatus,
        getGoalsForDateRange,
        getGoalsMatchingPredicate,
        getGoalsRequiringAttention;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, SetParentLogEntry, StatusLogEntry;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/goal_detail.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../styles.dart' show lightBackground, multiSplitViewThemeData, uiUnit;
import 'goal_list.dart' show GoalListWidget;
import 'hover_actions.dart';
import 'text_editing_controls.dart';

class GoalViewer extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewer({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewer> createState() => _GoalViewerState();
}

enum TimeSlice {
  today(null, "Today"),
  this_week(TimeSlice.today, "This Week"),
  this_month(TimeSlice.this_week, "This Month"),
  this_quarter(TimeSlice.this_month, "This Quarter"),
  this_year(TimeSlice.this_quarter, "This Year"),
  long_term(TimeSlice.this_year, "Long Term");

  const TimeSlice(this.zoomDown, this.displayName);

  final TimeSlice? zoomDown;
  final String displayName;

  DateTime? startTime(DateTime now) {
    switch (this) {
      case TimeSlice.today:
        return now.startOfDay;
      case TimeSlice.this_week:
        return now.startOfWeek;
      case TimeSlice.this_month:
        return now.startOfMonth;
      case TimeSlice.this_quarter:
        return now.startOfQuarter;
      case TimeSlice.this_year:
        return now.startOfYear;
      case TimeSlice.long_term:
        return null;
    }
  }

  DateTime? endTime(DateTime now) {
    switch (this) {
      case TimeSlice.today:
        return now.endOfDay;
      case TimeSlice.this_week:
        return now.endOfWeek;
      case TimeSlice.this_month:
        return now.endOfMonth;
      case TimeSlice.this_quarter:
        return now.endOfQuarter;
      case TimeSlice.this_year:
        return now.endOfYear;
      case TimeSlice.long_term:
        return null;
    }
  }
}

enum GoalFilter {
  pending(displayName: "Pending Goals"),
  all(displayName: "All Goals"),
  to_review(displayName: "To Review"),
  today(displayName: "Today"),
  this_week(displayName: "This Week"),
  this_month(displayName: "This Month"),
  this_quarter(displayName: "This Quarter"),
  this_year(displayName: "This Year"),
  long_term(displayName: "Long Term"),
  schedule(displayName: "Scheduled Goals");

  const GoalFilter({required this.displayName});

  final String displayName;
}

enum GoalViewMode { tree, list }

class _GoalViewerState extends ConsumerState<GoalViewer> {
  GoalFilter _filter = GoalFilter.schedule;
  GoalViewMode _mode = GoalViewMode.tree;
  bool shiftHeld = false;
  bool ctrlHeld = false;
  late final focusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.shiftLeft) {
          shiftHeld = true;
        } else if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.metaLeft) {
          ctrlHeld = true;
        }
      } else if (event is KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.shiftLeft) {
          shiftHeld = false;
        } else if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.metaLeft) {
          ctrlHeld = false;
        }
      }
      return KeyEventResult.ignored;
    },
  );

  Future<void>? openBoxFuture;
  bool isInitted = false;
  final _multiSplitViewController = MultiSplitViewController(areas: [
    Area(
      size: 200,
      minimalSize: 200,
      key: const ValueKey('viewSwitcher'),
    ),
    Area(
      weight: 0.5,
      minimalSize: 200,
      key: const ValueKey('list'),
      flex: true,
    ),
    Area(
      weight: 0.5,
      minimalSize: 200,
      key: const ValueKey('detail'),
      flex: true,
    )
  ]);

  onSelected(String goalId) {
    setState(() {
      ref.read(selectedGoalsProvider.notifier).toggle(goalId);
      Hive.box('goals_web.ui')
          .put('selectedGoals', ref.read(selectedGoalsProvider).toList());
    });
  }

  onSwitchFilter(GoalFilter filter) {
    setState(() {
      ref.read(selectedGoalsProvider.notifier).clear();
      _filter = filter;
    });
    Hive.box('goals_web.ui').put('goalViewerFilter', filter.name);
  }

  onSwitchDisplayMode(GoalViewMode mode) {
    setState(() {
      _mode = mode;
    });
    Hive.box('goals_web.ui').put('goalViewerDisplayMode', mode.name);
  }

  onExpanded(String goalId, {bool? expanded}) {
    setState(() {
      ref.read(expandedGoalsProvider.notifier).toggle(goalId);
      Hive.box('goals_web.ui')
          .put('expandedGoals', ref.read(expandedGoalsProvider).toList());
    });
  }

  onFocused(String? goalId) {
    setState(() {
      if (goalId != null) {
        final selectedGoals = ref.read(selectedGoalsProvider.notifier);
        if (!ctrlHeld) {
          selectedGoals.clear();
        }

        selectedGoals.add(goalId);
      }

      ref.read(focusedGoalProvider.notifier).set(goalId);
      Hive.box('goals_web.ui').put('focusedGoal', goalId);
    });
  }

  _onAddGoal(String? parentId, String text, [TimeSlice? timeSlice]) {
    final id = const Uuid().v4();
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: id,
        text: text,
        logEntry: SetParentLogEntry(
            id: Uuid().v4(),
            parentId: parentId,
            creationTime: DateTime.now())));

    if (timeSlice != null) {
      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
          id: id,
          logEntry: StatusLogEntry(
              id: const Uuid().v4(),
              creationTime: DateTime.now(),
              status: GoalStatus.active,
              // Setting startTime in the past might seem unintuitive, but this avoids the goal showing up
              // in the smaller time period in the case that we're at the
              // end of the larger time period
              // e.g. if we're in the last quarter of the year and we add a goal for the year
              // we don't want it to show up for "This Quarter" even though
              // This year and this quarter end at the same time.
              startTime: timeSlice.startTime(DateTime.now()),
              endTime: timeSlice.endTime(DateTime.now()))));
    }
  }

  _onSetStatus(String? goalId, GoalStatus? status,
      {DateTime? startTime, DateTime? endTime}) {
    final List<GoalDelta> goalDeltas = [];
    final selectedGoals = ref.read(selectedGoalsProvider);
    if (goalId == null || selectedGoals.contains(goalId)) {
      for (final String selectedGoalId in selectedGoals) {
        goalDeltas.add(GoalDelta(
          id: selectedGoalId,
          logEntry: StatusLogEntry(
            id: const Uuid().v4(),
            creationTime: DateTime.now(),
            status: status,
            startTime: startTime ?? DateTime.now(),
            endTime: endTime,
          ),
        ));
      }
    } else {
      goalDeltas.add(GoalDelta(
        id: goalId,
        logEntry: StatusLogEntry(
          id: const Uuid().v4(),
          creationTime: DateTime.now(),
          status: status,
          startTime: startTime ?? DateTime.now(),
          endTime: endTime,
        ),
      ));
    }

    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    ref.read(selectedGoalsProvider.notifier).clear();
  }

  onUnarchive(String? goalId) {
    this._onSetStatus(goalId, null);
  }

  onArchive(String? goalId) {
    this._onSetStatus(goalId, GoalStatus.archived);
  }

  onDone(String? goalId, DateTime? endDate) {
    var focusedGoalId = this.ref.read(focusedGoalProvider);
    if (focusedGoalId == goalId ||
        this
            .ref
            .read(selectedGoalsProvider)
            .containsAll([focusedGoalId, goalId])) {
      this.ref.read(focusedGoalProvider.notifier).set(null);
    }
    this._onSetStatus(goalId, GoalStatus.done, endTime: endDate);
  }

  onSnooze(String? goalId, DateTime? endDate) {
    this._onSetStatus(goalId, GoalStatus.pending, endTime: endDate);
  }

  onActive(String? goalId, {DateTime? startTime, DateTime? endTime}) {
    this._onSetStatus(goalId, GoalStatus.active,
        startTime: startTime, endTime: endTime);
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

    focusNode.requestFocus();

    if (!isInitted) {
      window.addEventListener('popstate', _handlePopState);
      setState(() {
        openBoxFuture = Hive.openBox('goals_web.ui').then((box) {
          if (mounted) {
            final focusedGoalId = _parseUrlGoalId();
            if (focusedGoalId != null) {
              ref.read(focusedGoalProvider.notifier).set(focusedGoalId);
              ref.read(selectedGoalsProvider.notifier).add(focusedGoalId);
            }
            ref.read(selectedGoalsProvider.notifier).addAll(
                (box.get('selectedGoals', defaultValue: <String>[])
                        as List<dynamic>)
                    .cast<String>());
            ref.read(expandedGoalsProvider.notifier).addAll(
                (box.get('expandedGoals', defaultValue: <String>[])
                        as List<dynamic>)
                    .cast<String>());

            final modeString = box.get('goalViewerDisplayMode',
                defaultValue: GoalViewMode.tree.name);
            try {
              _mode = GoalViewMode.values.byName(modeString);
            } catch (_) {
              _mode = GoalViewMode.tree;
            }
            final filterString = box.get('goalViewerFilter',
                defaultValue: GoalFilter.schedule.name);
            try {
              _filter = GoalFilter.values.byName(filterString);
            } catch (_) {
              _filter = GoalFilter.to_review;
            }
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

  _viewSwitcher(bool drawer) {
    final sidebarFilters = [
      GoalFilter.schedule,
      GoalFilter.to_review,
      GoalFilter.all,
    ];
    return SizedBox(
      key: const ValueKey('viewSwitcher'),
      width: 200,
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
          for (final filter in sidebarFilters)
            ListTile(
              title: Text(filter.displayName),
              selected: _filter == filter,
              onTap: () {
                // Update the state of the app
                onSwitchFilter(filter);
                if (drawer) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusedGoalId = ref.watch(focusedGoalProvider);
    final worldContext = ref.watch(worldContextProvider);
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final isEditingText = ref.watch(isEditingTextProvider);
    ref.listen(focusedGoalProvider, _handleFocusedGoalChange);

    final children = <Widget>[];

    final isNarrow = MediaQuery.of(context).size.width < 600;
    if (!isNarrow) {
      children.add(_viewSwitcher(false));
    }

    var appBarTitle = 'Glass Goals';
    if (!isNarrow || focusedGoalId == null) {
      children.add(_listView(worldContext));
      if (isNarrow) {
        appBarTitle = _filter.displayName;
      }
    }

    if (focusedGoalId != null) {
      children.add(_detailView());
      if (isNarrow) {
        appBarTitle = widget.goalMap[focusedGoalId]!.text;
      }
    }

    return RawKeyboardListener(
      focusNode: focusNode,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              SizedBox(
                width: uiUnit(12),
                height: uiUnit(12),
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(0, uiUnit(2), uiUnit(2), uiUnit(2)),
                  child: SvgPicture.asset(
                    'assets/logo.svg',
                  ),
                ),
              ),
              Text(appBarTitle),
            ],
          ),
          centerTitle: false,
          leading: isNarrow
              ? focusedGoalId != null
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
              : null,
        ),
        drawer: isNarrow && focusedGoalId == null
            ? Drawer(
                child: _viewSwitcher(true),
              )
            : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: children.length == 1
                  ? children[0]
                  : MultiSplitViewTheme(
                      data: multiSplitViewThemeData,
                      child: MultiSplitView(
                        controller: _multiSplitViewController,
                        children: children,
                      )),
            ),
            if (isNarrow && (selectedGoals.isNotEmpty || focusedGoalId != null))
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: uiUnit(16),
                  child: Container(
                    color: lightBackground,
                    child: isEditingText
                        ? const TextEditingControls()
                        : HoverActionsWidget(
                            onUnarchive: onUnarchive,
                            onArchive: onArchive,
                            onDone: onDone,
                            onSnooze: onSnooze,
                            onActive: onActive,
                            goalMap: widget.goalMap,
                            mainAxisSize: MainAxisSize.max,
                          ),
                  ))
          ],
        ),
      ),
    );
  }

  Widget? _timeSlice(WorldContext context, TimeSlice slice) {
    final goalMap = getGoalsForDateRange(
        context,
        widget.goalMap,
        slice.startTime(context.time),
        slice.endTime(context.time),
        slice.zoomDown?.startTime(context.time),
        slice.zoomDown?.endTime(context.time));

    if (goalMap.isEmpty && slice.zoomDown != null) {
      return null;
    }
    final goalIds = _mode == GoalViewMode.tree
        ? goalMap.values
            .where((goal) {
              for (final superGoal in goal.superGoals) {
                if (goalMap.containsKey(superGoal.id)) {
                  return false;
                }
              }
              return true;
            })
            .map((e) => e.id)
            .toList()
        : (goalMap.values.toList(growable: false)
              ..sort((a, b) =>
                  a.text.toLowerCase().compareTo(b.text.toLowerCase())))
            .map((g) => g.id)
            .toList();
    return GoalListWidget(
      goalMap: goalMap,
      goalIds: goalIds,
      onSelected: onSelected,
      onExpanded: onExpanded,
      onFocused: onFocused,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        onUnarchive: onUnarchive,
        onArchive: onArchive,
        onDone: onDone,
        onSnooze: onSnooze,
        onActive: onActive,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
      onAddGoal: (String? parentId, String text) =>
          this._onAddGoal(parentId, text, slice),
    );
  }

  Widget? _previousTimeSliceGoals(WorldContext context, TimeSlice slice) {
    final endOfPreviousSlice =
        slice.startTime(context.time)?.subtract(const Duration(seconds: 1));

    if (endOfPreviousSlice == null) {
      return null;
    }
    final yesterdayContext = WorldContext(time: endOfPreviousSlice);

    var goalMap = getGoalsForDateRange(
      yesterdayContext,
      widget.goalMap,
      slice.startTime(yesterdayContext.time),
      slice.endTime(yesterdayContext.time),
      slice.zoomDown?.startTime(yesterdayContext.time),
      slice.zoomDown?.endTime(yesterdayContext.time),
    );

    goalMap = {
      for (final key in goalMap.keys)
        if (getGoalStatus(context, goalMap[key]!).status == null)
          key: goalMap[key]!
    };

    final goalIds = _mode == GoalViewMode.tree
        ? goalMap.values
            .where((goal) {
              for (final superGoal in goal.superGoals) {
                if (goalMap.containsKey(superGoal.id)) {
                  return false;
                }
              }
              return true;
            })
            .map((e) => e.id)
            .toList()
        : (goalMap.values.toList(growable: false)
              ..sort((a, b) =>
                  a.text.toLowerCase().compareTo(b.text.toLowerCase())))
            .map((g) => g.id)
            .toList();

    if (goalMap.isEmpty || goalIds.isEmpty) {
      return null;
    }

    return GoalListWidget(
      goalMap: goalMap,
      goalIds: goalIds,
      onSelected: onSelected,
      onExpanded: onExpanded,
      onFocused: onFocused,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        onUnarchive: onUnarchive,
        onArchive: onArchive,
        onDone: onDone,
        onSnooze: onSnooze,
        onActive: onActive,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
    );
  }

  Widget? _orphanedGoals(WorldContext context) {
    final goalMap = getGoalsRequiringAttention(context, widget.goalMap);

    final goalIds = _mode == GoalViewMode.tree
        ? goalMap.values
            .where((goal) {
              for (final superGoal in goal.superGoals) {
                if (goalMap.containsKey(superGoal.id)) {
                  return false;
                }
              }
              return true;
            })
            .map((e) => e.id)
            .toList()
        : (goalMap.values.toList(growable: false)
              ..sort((a, b) =>
                  a.text.toLowerCase().compareTo(b.text.toLowerCase())))
            .map((g) => g.id)
            .toList();

    if (goalMap.isEmpty || goalIds.isEmpty) {
      return null;
    }
    return GoalListWidget(
      goalMap: goalMap,
      goalIds: goalIds,
      onSelected: onSelected,
      onExpanded: onExpanded,
      onFocused: onFocused,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        onUnarchive: onUnarchive,
        onArchive: onArchive,
        onDone: onDone,
        onSnooze: onSnooze,
        onActive: onActive,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
    );
  }

  Widget _listView(WorldContext worldContext) {
    final theme = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Column(
      key: const ValueKey('list'),
      children: [
        if (!isNarrow)
          Padding(
            padding: EdgeInsets.all(uiUnit(2)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _filter.displayName,
                  style: theme.headlineMedium,
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
              child: FutureBuilder<void>(
                  future: openBoxFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Text('Loading...');
                    }
                    var goalMap = widget.goalMap;
                    switch (_filter) {
                      case GoalFilter.all:
                        final goalIds = _mode == GoalViewMode.tree
                            ? goalMap.values
                                .where((goal) {
                                  for (final superGoal in goal.superGoals) {
                                    if (goalMap.containsKey(superGoal.id)) {
                                      return false;
                                    }
                                  }
                                  return true;
                                })
                                .map((e) => e.id)
                                .toList()
                            : (goalMap.values.toList(growable: false)
                                  ..sort((a, b) => a.text
                                      .toLowerCase()
                                      .compareTo(b.text.toLowerCase())))
                                .map((g) => g.id)
                                .toList();
                        return GoalListWidget(
                          goalMap: goalMap,
                          goalIds: goalIds,
                          onSelected: onSelected,
                          onExpanded: onExpanded,
                          onFocused: onFocused,
                          hoverActionsBuilder: (goalId) => HoverActionsWidget(
                            goalId: goalId,
                            onUnarchive: onUnarchive,
                            onArchive: onArchive,
                            onDone: onDone,
                            onSnooze: onSnooze,
                            onActive: onActive,
                            goalMap: widget.goalMap,
                          ),
                          depthLimit: _mode == GoalViewMode.list ? 1 : null,
                          onAddGoal: this._onAddGoal,
                        );
                      case GoalFilter.to_review:
                        final toReview = {
                          'Orphaned Goals': _orphanedGoals(worldContext),
                          'Yesterday\'s Active Goals': _previousTimeSliceGoals(
                              worldContext, TimeSlice.today),
                        };

                        final nothingToReview =
                            toReview.values.every((element) => element == null);

                        return nothingToReview
                            ? Text('All caught up!', style: theme.headlineSmall)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    for (final entry in toReview.entries)
                                      if (entry.value != null) ...[
                                        Padding(
                                          padding: EdgeInsets.all(uiUnit(2)),
                                          child: Text(entry.key,
                                              style: theme.headlineSmall),
                                        ),
                                        entry.value!
                                      ]
                                  ]);
                      case GoalFilter.pending:
                        goalMap = getGoalsMatchingPredicate(
                            worldContext,
                            widget.goalMap,
                            (goal) =>
                                getGoalStatus(worldContext, goal).status !=
                                    GoalStatus.archived &&
                                getGoalStatus(worldContext, goal).status !=
                                    GoalStatus.done);
                        final goalIds = _mode == GoalViewMode.tree
                            ? goalMap.values
                                .where((goal) {
                                  for (final superGoal in goal.superGoals) {
                                    if (goalMap.containsKey(superGoal.id)) {
                                      return false;
                                    }
                                  }
                                  return true;
                                })
                                .map((e) => e.id)
                                .toList()
                            : (goalMap.values.toList(growable: false)
                                  ..sort((a, b) => a.text
                                      .toLowerCase()
                                      .compareTo(b.text.toLowerCase())))
                                .map((g) => g.id)
                                .toList();
                        return GoalListWidget(
                          goalMap: goalMap,
                          goalIds: goalIds,
                          onSelected: onSelected,
                          onExpanded: onExpanded,
                          onFocused: onFocused,
                          hoverActionsBuilder: (goalId) => HoverActionsWidget(
                              goalId: goalId,
                              onUnarchive: onUnarchive,
                              onArchive: onArchive,
                              onDone: onDone,
                              onSnooze: onSnooze,
                              onActive: onActive,
                              goalMap: widget.goalMap),
                          depthLimit: _mode == GoalViewMode.list ? 1 : null,
                          onAddGoal: this._onAddGoal,
                        );
                      case GoalFilter.today:
                        final additionalSections = {
                          'Yesterday': _previousTimeSliceGoals(
                              worldContext, TimeSlice.today),
                          'This Week':
                              _timeSlice(worldContext, TimeSlice.this_week),
                        };
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _timeSlice(worldContext, TimeSlice.today) ??
                                  Text('No Goals!'),
                              for (final entry in additionalSections.entries)
                                if (entry.value != null) ...[
                                  Padding(
                                    padding: EdgeInsets.all(uiUnit(2)),
                                    child: Text(entry.key,
                                        style: theme.headlineSmall),
                                  ),
                                  entry.value!
                                ]
                            ]);
                      case GoalFilter.this_week:
                        return _timeSlice(worldContext, TimeSlice.this_week) ??
                            Text('No Goals!');
                      case GoalFilter.this_month:
                        return _timeSlice(worldContext, TimeSlice.this_month) ??
                            Text('No Goals!');
                      case GoalFilter.this_quarter:
                        return _timeSlice(
                                worldContext, TimeSlice.this_quarter) ??
                            Text('No Goals!');
                      case GoalFilter.this_year:
                        return _timeSlice(worldContext, TimeSlice.this_year) ??
                            Text('No Goals!');
                      case GoalFilter.long_term:
                        return _timeSlice(worldContext, TimeSlice.long_term) ??
                            Text('No Goals!');
                      case GoalFilter.schedule:
                        final children = <Widget>[];

                        for (final timeSlice in [
                          TimeSlice.today,
                          TimeSlice.this_week,
                          TimeSlice.this_month,
                          TimeSlice.this_quarter,
                          TimeSlice.this_year,
                          TimeSlice.long_term
                        ]) {
                          final slice = _timeSlice(worldContext, timeSlice);
                          if (slice != null) {
                            children.addAll([
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: uiUnit(2)),
                                child: TextButton(
                                  onPressed: () => {
                                    // kinda gross that we're sharing names between enums here but w/e
                                    onSwitchFilter(GoalFilter.values
                                        .byName(timeSlice.name))
                                  },
                                  child: Text(
                                    timeSlice.displayName,
                                    style: theme.headlineSmall,
                                  ),
                                ),
                              ),
                              slice,
                            ]);
                          }
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        );
                    }
                  })),
        ),
      ],
    );
  }

  Widget _detailView() {
    final focusedGoalId = ref.watch(focusedGoalProvider);
    final focusedGoal = widget.goalMap[focusedGoalId];
    if (focusedGoal == null) {
      return Container();
    }

    return SingleChildScrollView(
      key: const ValueKey('detail'),
      child: GoalDetail(
        goal: focusedGoal,
        goalMap: widget.goalMap,
        onExpanded: this.onExpanded,
        onFocused: this.onFocused,
        onSelected: this.onSelected,
        onAddGoal: (String? parentId, String text) =>
            this._onAddGoal(parentId ?? focusedGoalId, text),
        hoverActionsBuilder: (goalId) => HoverActionsWidget(
            goalId: goalId,
            onUnarchive: this.onUnarchive,
            onArchive: this.onArchive,
            onDone: this.onDone,
            onSnooze: this.onSnooze,
            onActive: this.onActive,
            goalMap: widget.goalMap),
      ),
    );
  }
}
