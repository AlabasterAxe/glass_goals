import 'dart:html';

import 'package:flutter/material.dart'
    show
        Colors,
        Dialog,
        Drawer,
        Icons,
        ListTile,
        MenuAnchor,
        MenuController,
        MenuItemButton,
        Scaffold,
        Theme,
        Tooltip,
        showDialog;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getGoalPriority,
        getGoalStatus,
        getGoalsForDateRange,
        getGoalsMatchingPredicate,
        getGoalsRequiringAttention,
        getPreviouslyActiveGoals,
        getTransitiveSubGoals;
import 'package:goals_core/sync.dart'
    show
        GoalDelta,
        GoalStatus,
        PriorityLogEntry,
        SetParentLogEntry,
        StatusLogEntry;
import 'package:goals_web/app_bar.dart';
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/flattened_goal_tree.dart';
import 'package:goals_web/goal_viewer/goal_detail.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/scheduled_goals_v2.dart';
import 'package:goals_web/intents.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../common/keyboard_utils.dart';
import '../common/time_slice.dart';
import '../debug/debug_sync_info.dart' show DebugSyncInfo;
import '../styles.dart'
    show
        darkElementColor,
        lightBackground,
        multiSplitViewThemeData,
        smallTextStyle,
        uiUnit;
import '../widgets/gg_icon_button.dart';
import 'goal_actions_context.dart';
import 'goal_search_modal.dart';
import 'goal_viewer_constants.dart';
import 'hover_actions.dart';
import 'text_editing_controls.dart';

class GoalViewer extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewer({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewer> createState() => _GoalViewerState();
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
  schedule(displayName: "Scheduled Goals"),
  schedule_v2(displayName: "Pending Goals");

  const GoalFilter({required this.displayName});

  final String displayName;
}

enum GoalViewMode { tree, list, schedule }

class _GoalViewerState extends ConsumerState<GoalViewer> {
  GoalFilter _filter = GoalFilter.schedule;
  GoalViewMode _mode = GoalViewMode.tree;
  final FocusNode _focusNode = FocusNode();
  bool _isDebug = false;

  Future<void>? openBoxFuture;
  bool isInitted = false;
  late MultiSplitViewController _multiSplitViewController =
      this._getMultiSplitViewController(false);

  final _addTimeSliceMenuController = MenuController();

  _onSelected(String goalId) {
    setState(() {
      final Set<String> selectedGoals =
          isCtrlHeld() ? selectedGoalsStream.value : {};
      selectedGoals.add(goalId);

      selectedGoalsStream.add(selectedGoals);
      Hive.box('goals_web.ui')
          .put('selectedGoals', selectedGoalsStream.value.toList());
    });
  }

  _onSwitchFilter(GoalFilter filter) {
    setState(() {
      selectedGoalsStream.add({});
      focusedGoalStream.add(null);
      _filter = filter;
    });
    Hive.box('goals_web.ui').put('goalViewerFilter', filter.name);
  }

  _onExpanded(String goalId, {bool? expanded}) {
    setState(() {
      toggleId(expandedGoalsStream, goalId);
      Hive.box('goals_web.ui')
          .put('expandedGoals', expandedGoalsStream.value.toList());
    });
  }

  _onFocused(String? goalId) {
    setState(() {
      if (goalId != null) {
        final Set<String> selectedGoals =
            isCtrlHeld() ? selectedGoalsStream.value : {};
        selectedGoals.add(goalId);

        selectedGoalsStream.add(selectedGoals);
      }

      focusedGoalStream.add(goalId);
      Hive.box('goals_web.ui').put('focusedGoal', goalId);
    });
  }

  _onAddGoal(String? parentId, String text, [TimeSlice? timeSlice]) {
    final id = const Uuid().v4();
    final goalDeltas = <GoalDelta>[
      GoalDelta(
          id: id,
          text: text,
          logEntry: SetParentLogEntry(
              id: Uuid().v4(),
              parentId: parentId,
              creationTime: DateTime.now())),
    ];

    if (timeSlice != null && timeSlice != TimeSlice.unscheduled) {
      goalDeltas.add(GoalDelta(
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
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  _onSetStatus(String? goalId, GoalStatus? status,
      {DateTime? startTime, DateTime? endTime}) {
    final List<GoalDelta> goalDeltas = [];
    final selectedGoals = selectedGoalsStream.value;
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
    selectedGoalsStream.add({});
  }

  _onUnarchive(String? goalId) {
    this._onSetStatus(goalId, null);
  }

  _onArchive(String? goalId) {
    this._onSetStatus(goalId, GoalStatus.archived);
  }

  _onDone(String? goalId, DateTime? endDate) {
    var focusedGoalId = this.ref.read(focusedGoalProvider);
    if (focusedGoalId == goalId ||
        selectedGoalsStream.value.containsAll([focusedGoalId, goalId])) {
      focusedGoalStream.add(null);
    }
    this._onSetStatus(goalId, GoalStatus.done, endTime: endDate);
  }

  _onSnooze(String? goalId, DateTime? endDate) {
    this._onSetStatus(goalId, GoalStatus.pending, endTime: endDate);
  }

  onActive(String? goalId, {DateTime? startTime, DateTime? endTime}) {
    this._onSetStatus(goalId, GoalStatus.active,
        startTime: startTime, endTime: endTime);
  }

  _handlePopState(_) {
    final focusedGoalId = ref.read(focusedGoalProvider);
    if (_parseUrlGoalId() != focusedGoalId) {
      focusedGoalStream.add(_parseUrlGoalId());
    }
  }

  String? _parseUrlGoalId() {
    final parts = window.location.href.split('/');
    if (parts.length >= 3 && parts[parts.length - 2] == 'goal') {
      return parts[parts.length - 1];
    }
    return null;
  }

  _getMultiSplitViewController(bool debugMode) {
    return MultiSplitViewController(areas: [
      Area(
        size: 200,
        minimalSize: 200,
        key: const ValueKey('viewSwitcher'),
      ),
      Area(
        weight: debugMode ? 1 / 3 : 1 / 2,
        minimalSize: 400,
        key: const ValueKey('list'),
        flex: true,
        collapseSize: 200,
      ),
      Area(
        weight: debugMode ? 1 / 3 : 1 / 2,
        minimalSize: 400,
        key: const ValueKey('detail'),
        flex: true,
      ),
      if (debugMode)
        Area(
          weight: 1 / 3,
          minimalSize: 200,
          key: const ValueKey('debug'),
          flex: true,
        )
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _focusNode.requestFocus();

    if (!isInitted) {
      window.addEventListener('popstate', _handlePopState);
      setState(() {
        openBoxFuture = Hive.openBox('goals_web.ui').then((box) {
          if (mounted) {
            final focusedGoalId = _parseUrlGoalId();
            if (focusedGoalId != null) {
              focusedGoalStream.add(focusedGoalId);
              addId(selectedGoalsStream, focusedGoalId);
            }
            selectedGoalsStream.add({
              ...(box.get('selectedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>()
            });
            expandedGoalsStream.add({
              ...(box.get('expandedGoals', defaultValue: <String>[])
                      as List<dynamic>)
                  .cast<String>()
            });

            final modeString = box.get('goalViewerDisplayMode',
                defaultValue: GoalViewMode.tree.name);
            try {
              _mode = GoalViewMode.values.byName(modeString);
            } catch (_) {
              _mode = GoalViewMode.tree;
            }
            final filterString = box.get('goalViewerFilter',
                defaultValue: GoalFilter.schedule_v2.name);

            try {
              _filter = filterString == GoalFilter.schedule.name
                  ? GoalFilter.schedule_v2
                  : GoalFilter.values.byName(filterString);
            } catch (_) {
              _filter = GoalFilter.schedule_v2;
            }
          }
        });
        isInitted = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      if (ref.read(debugProvider)) {
        this.setState(() {
          this._multiSplitViewController =
              this._getMultiSplitViewController(true);
          this._isDebug = true;
        });
      }
    });
  }

  @override
  dispose() {
    window.removeEventListener('popstate', _handlePopState);
    super.dispose();
  }

  _handleFocusedGoalChange(
      AsyncValue<String?>? prevGoalId, AsyncValue<String?>? newGoalId) {
    if (prevGoalId?.value == newGoalId?.value) {
      return;
    }
    if (newGoalId?.value == null) {
      window.history.pushState(null, 'home', '/home');
    } else if (!window.location.href.endsWith('goal/${newGoalId!.value}')) {
      window.history.pushState(null, 'home', '/home/goal/${newGoalId.value}');
    }
  }

  _viewSwitcher(bool drawer, WorldContext worldContext, bool debug) {
    final sidebarFilters = [
      GoalFilter.schedule_v2,
      GoalFilter.to_review,
      GoalFilter.all,
    ];

    final toReview = {
      ...getGoalsRequiringAttention(worldContext, widget.goalMap),
      ...getPreviouslyActiveGoals(
        worldContext,
        widget.goalMap,
      )
    };
    final theme = Theme.of(context);
    return SizedBox(
      key: const ValueKey('viewSwitcher'),
      width: 200,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final filter in sidebarFilters)
            ListTile(
              title: Text(filter.displayName),
              selected: _filter == filter,
              contentPadding: EdgeInsets.symmetric(horizontal: uiUnit(2)),
              trailing: (filter == GoalFilter.to_review && toReview.isNotEmpty)
                  ? // material theme container with rounded corners and toReview size
                  Container(
                      width: uiUnit(8),
                      height: uiUnit(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(uiUnit(2)),
                      ),
                      child: Center(
                        child: Text(
                          toReview.length.toString(),
                          style:
                              smallTextStyle.copyWith(color: darkElementColor),
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                this._onSwitchFilter(filter);

                this._multiSplitViewController.resetSizes();

                if (drawer) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }

  List<GoalDelta> _computeDropOnSeparatorEffects(Set<String> goalIds,
      List<String> prevGoalPath, List<String> nextGoalPath) {
    final List<GoalDelta> goalDeltas = [];

    final prevGoalId = prevGoalPath.lastOrNull;
    final nextGoalId = nextGoalPath.lastOrNull;

    final worldContext = WorldContext.now();

    String? newParentId;
    double? newPriority;
    if (prevGoalPath.length == nextGoalPath.length) {
      // dropped between siblings
      newParentId = prevGoalPath.length >= 3
          ? prevGoalPath[prevGoalPath.length - 2]
          : null;

      final prevPriority = prevGoalId == null
          ? null
          : getGoalPriority(WorldContext.now(), widget.goalMap[prevGoalId]!);
      final nextPriority = nextGoalId == null ||
              nextGoalId == NEW_GOAL_PLACEHOLDER
          ? null
          : getGoalPriority(WorldContext.now(), widget.goalMap[nextGoalId]!);

      if (nextPriority != null && prevPriority != null) {
        newPriority = (prevPriority + nextPriority) / 2;
      } else if (prevPriority != null) {
        newPriority = null;
      }
    } else if (prevGoalPath.length == nextGoalPath.length - 1) {
      // dropped between parent and child
      newParentId = prevGoalPath.length > 1 ? prevGoalPath.lastOrNull : null;
      newPriority = nextGoalId == NEW_GOAL_PLACEHOLDER
          ? null
          : getGoalPriority(worldContext, widget.goalMap[nextGoalId]!) / 2;
    } else if (prevGoalPath.length > nextGoalPath.length) {
      // dropped after last child and before add goal entry

      newParentId = nextGoalPath.length >= 3
          ? nextGoalPath[nextGoalPath.length - 2]
          : null;

      final addGoalParentId = prevGoalPath.length >= 3
          ? prevGoalPath[prevGoalPath.length - 2]
          : null;
      final prevGoal = widget.goalMap[addGoalParentId];
      final prevPriority =
          prevGoal == null ? null : getGoalPriority(worldContext, prevGoal);
      final nextPriority =
          nextGoalId == null || nextGoalId == NEW_GOAL_PLACEHOLDER
              ? null
              : getGoalPriority(worldContext, widget.goalMap[nextGoalId]!);

      if (nextPriority != null && prevPriority != null) {
        newPriority = (prevPriority + nextPriority) / 2;
      } else if (prevPriority != null) {
        newPriority = null;
      }
    }

    for (final goalId in goalIds) {
      final droppedGoal = this.widget.goalMap[goalId];
      if (newParentId != null &&
          droppedGoal != null &&
          !droppedGoal.hasParent(newParentId)) {
        goalDeltas.add(GoalDelta(
            id: goalId,
            logEntry: SetParentLogEntry(
                id: Uuid().v4(),
                parentId: newParentId,
                creationTime: DateTime.now())));
      }

      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: PriorityLogEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              priority: newPriority)));
    }

    return goalDeltas;
  }

  List<GoalDelta> _computeDropOnGoalEffects(
      Set<String> goalIds, List<String> targetGoalPath) {
    final List<GoalDelta> goalDeltas = [];
    for (final goalId in goalIds) {
      final droppedGoal = this.widget.goalMap[goalId];

      if (droppedGoal == null || droppedGoal.hasParent(goalId)) {
        continue;
      }
      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: SetParentLogEntry(
              id: Uuid().v4(),
              parentId: targetGoalPath.lastOrNull,
              creationTime: DateTime.now())));
    }
    return goalDeltas;
  }

  List<GoalDelta> _computeDropGoalEffects(
    String droppedGoalId, {
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) {
    final selectedGoals = selectedGoalsStream.value;
    final goalsToUpdate =
        selectedGoals.contains(droppedGoalId) ? selectedGoals : {droppedGoalId};

    if (!((dropPath != null) ^
        (prevDropPath != null && nextDropPath != null))) {
      throw Exception(
          'Exactly one of goalPath or prevGoalPath and nextGoalPath must be non-null');
    }

    if (prevDropPath != null && nextDropPath != null) {
      return this._computeDropOnSeparatorEffects(
          goalsToUpdate, prevDropPath, nextDropPath);
    } else {
      return this._computeDropOnGoalEffects(goalsToUpdate, dropPath!);
    }
  }

  _onDropGoal(
    String droppedGoalId, {
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) {
    final goalDeltas = _computeDropGoalEffects(
      droppedGoalId,
      dropPath: dropPath,
      prevDropPath: prevDropPath,
      nextDropPath: nextDropPath,
    );
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoalsStream.add({});
  }

  @override
  Widget build(BuildContext context) {
    final focusedGoalId =
        ref.watch(focusedGoalProvider).value ?? focusedGoalStream.value;
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final selectedGoals =
        ref.watch(selectedGoalsProvider).value ?? selectedGoalsStream.value;
    final textEditingPath = ref.watch(textFocusProvider).value;
    final isEditingText = ref.watch(isEditingTextProvider);
    ref.listen(focusedGoalProvider, _handleFocusedGoalChange);
    ref.listen(debugProvider, (_, isDebug) {
      setState(() {
        _isDebug = isDebug;
        _multiSplitViewController = _getMultiSplitViewController(isDebug);
      });
    });

    final children = <Widget>[];

    final singleScreen = MediaQuery.of(context).size.width < 600;
    final showHamburger = MediaQuery.of(context).size.width < 1000;
    if (!showHamburger) {
      children.add(_viewSwitcher(false, worldContext, this._isDebug));
    }

    var appBarTitle = 'Glass Goals';
    if (!singleScreen || focusedGoalId == null) {
      children.add(_listView(worldContext));
      if (singleScreen) {
        appBarTitle = _filter.displayName;
      }
    }

    if (focusedGoalId != null) {
      children.add(_detailView());
      if (singleScreen) {
        appBarTitle = widget.goalMap[focusedGoalId]!.text;
      }
    }

    if (!singleScreen && this._isDebug)
      children.add(
        Container(
          key: const ValueKey('debug'),
          color: Colors.black.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UI State', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Selected Goals: ${selectedGoals.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Text Focus: ${textEditingPath?.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text('Focused Thing: ${FocusManager.instance.primaryFocus}'),
              StreamBuilder<List<String>?>(
                  stream: hoverEventStream.stream,
                  builder: (context, snapshot) {
                    return Text('Hovered Path: ${snapshot.data}',
                        style: Theme.of(context).textTheme.bodySmall);
                  }),
              DebugSyncInfo(
                syncClient: AppContext.of(context).syncClient,
              ),
            ],
          ),
        ),
      );

    return GoalActionsContext(
      onActive: this.onActive,
      onArchive: this._onArchive,
      onDone: this._onDone,
      onExpanded: this._onExpanded,
      onSelected: this._onSelected,
      onSnooze: this._onSnooze,
      onUnarchive: this._onUnarchive,
      onAddGoal: this._onAddGoal,
      onFocused: this._onFocused,
      onDropGoal: this._onDropGoal,
      child: FocusableActionDetector(
        autofocus: true,
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
              const UndoIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
              const UndoIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyZ): const RedoIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyZ): const RedoIntent(),
        },
        actions: {
          SearchIntent: CallbackAction(onInvoke: _openSearch),
          UndoIntent: CallbackAction(onInvoke: (_) {
            AppContext.of(context).syncClient.undo();
          }),
          RedoIntent: CallbackAction(onInvoke: (_) {
            AppContext.of(context).syncClient.redo();
          }),
        },
        child: FocusScope(
          child: Scaffold(
            appBar: GlassGoalsAppBar(
              appBarTitle: appBarTitle,
              isNarrow: showHamburger,
              signedIn: true,
              onBack: () {
                focusedGoalStream.add(null);
              },
              focusedGoalId: focusedGoalId,
            ),
            drawer: showHamburger && focusedGoalId == null
                ? Drawer(
                    child: _viewSwitcher(true, worldContext, this._isDebug),
                  )
                : null,
            body: Stack(
              children: [
                Positioned.fill(
                  top: uiUnit(2),
                  child: children.isEmpty
                      ? Container()
                      : children.length == 1
                          ? children[0]
                          : MultiSplitViewTheme(
                              data: multiSplitViewThemeData,
                              child: MultiSplitView(
                                controller: _multiSplitViewController,
                                children: children,
                              )),
                ),
                if (singleScreen &&
                    (selectedGoals.isNotEmpty || focusedGoalId != null))
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
                                goalMap: widget.goalMap,
                                mainAxisSize: MainAxisSize.max,
                              ),
                      ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  _openSearch(_) async {
    final focusedGoalId = await showDialog(
        barrierColor: Colors.black26,
        context: context,
        builder: (context) => Dialog(
              surfaceTintColor: Colors.transparent,
              backgroundColor: lightBackground,
              alignment: FractionalOffset.topCenter,
              child: StreamBuilder<Map<String, Goal>>(
                  stream: AppContext.of(context).syncClient.stateSubject,
                  builder: (context, snapshot) => GoalSearchModal(
                        goalMap: snapshot.data ?? Map(),
                      )),
            ));
    if (focusedGoalId != null) {
      focusedGoalStream.add(focusedGoalId);
    }
  }

  Widget? _timeSlice(WorldContext context, TimeSlice slice) =>
      _timeSlices(context, [slice]).firstOrNull;

  List<TimeSlice> _computeCreateTimeSliceOptions(WorldContext worldContext,
      List<TimeSlice> possibleSlices, List<TimeSlice> manualTimeSlices) {
    final List<TimeSlice> result = [];
    final Set<String> goalsAccountedFor = {};
    for (final slice in possibleSlices) {
      final goalMap = getGoalsForDateRange(
        worldContext,
        widget.goalMap,
        slice.startTime(worldContext.time),
        slice.endTime(worldContext.time),
      );
      for (final goalId in goalsAccountedFor) {
        if (goalMap.containsKey(goalId)) {
          goalMap.remove(goalId);
        }
      }

      if (goalMap.isEmpty && !manualTimeSlices.contains(slice)) {
        result.add(slice);
        continue;
      }

      for (final goal in goalMap.values) {
        goalsAccountedFor.add(goal.id);
        goalsAccountedFor.addAll(getTransitiveSubGoals(goalMap, goal.id).keys);
      }
    }
    return result;
  }

  List<Widget> _timeSlices(WorldContext worldContext, List<TimeSlice> slices) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    for (final slice in slices) {
      final goalMap = getGoalsForDateRange(
        worldContext,
        widget.goalMap,
        slice.startTime(worldContext.time),
        slice.endTime(worldContext.time),
      );

      if (goalMap.isEmpty && slice.zoomDown != null) {
        continue;
      }

      for (final goalId in goalsAccountedFor.keys) {
        if (goalMap.containsKey(goalId)) {
          goalMap.remove(goalId);
        }
      }

      for (final goal in goalMap.values) {
        goalsAccountedFor[goal.id] = goal;
        goalsAccountedFor.addAll(getTransitiveSubGoals(goalMap, goal.id));
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
      result.add(Padding(
        padding: EdgeInsets.all(uiUnit(2)),
        child: Text(
          slice.displayName,
          style: Theme.of(this.context).textTheme.headlineSmall,
        ),
      ));
      result.add(Builder(builder: (context) {
        return GoalActionsContext.overrideWith(
          context,
          onAddGoal: (String? parentId, String text, [TimeSlice? _]) =>
              this._onAddGoal(parentId, text, slice),
          onDropGoal: (
            droppedGoalId, {
            List<String>? dropPath,
            List<String>? prevDropPath,
            List<String>? nextDropPath,
          }) {
            final goalDeltas = this._computeDropGoalEffects(
              droppedGoalId,
              dropPath: dropPath,
              prevDropPath: prevDropPath,
              nextDropPath: nextDropPath,
            );
            final goalsToUpdate =
                selectedGoalsStream.value.contains(droppedGoalId)
                    ? selectedGoalsStream.value
                    : {droppedGoalId};
            bool setNullParent = goalsToUpdate.every(goalMap.containsKey);
            bool addStatus =
                goalsToUpdate.every((goalId) => !goalMap.containsKey(goalId));
            for (final goalId in goalsToUpdate) {
              if (addStatus) {
                goalDeltas.add(GoalDelta(
                    id: goalId,
                    logEntry: StatusLogEntry(
                      id: const Uuid().v4(),
                      creationTime: DateTime.now(),
                      status: GoalStatus.active,
                      startTime: slice.startTime(worldContext.time),
                      endTime: slice.endTime(worldContext.time),
                    )));
              }

              if (setNullParent &&
                  (prevDropPath?.length == 0 || prevDropPath?.length == 1) &&
                  (nextDropPath?.length == 0 || nextDropPath?.length == 1)) {
                goalDeltas.add(GoalDelta(
                    id: goalId,
                    logEntry: SetParentLogEntry(
                        id: const Uuid().v4(),
                        parentId: null,
                        creationTime: DateTime.now())));
              }
            }

            selectedGoalsStream.add({});
            AppContext.of(context).syncClient.modifyGoals(goalDeltas);
          },
          child: FlattenedGoalTree(
            section: slice.name,
            goalMap: goalMap,
            rootGoalIds: goalIds,
            hoverActionsBuilder: (goalId) => HoverActionsWidget(
              goalId: goalId,
              goalMap: widget.goalMap,
            ),
            depthLimit: _mode == GoalViewMode.list ? 1 : null,
          ),
        );
      }));
    }
    return result;
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

    return FlattenedGoalTree(
      section: 'previous-${slice.name}',
      goalMap: goalMap,
      rootGoalIds: goalIds,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
    );
  }

  Widget? _previouslyActiveGoals(WorldContext context) {
    final goalMap = getPreviouslyActiveGoals(context, widget.goalMap);

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
    return FlattenedGoalTree(
      section: 'previously-active',
      goalMap: goalMap,
      rootGoalIds: goalIds,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
      showAddGoal: false,
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
    return FlattenedGoalTree(
      section: 'orphaned',
      goalMap: goalMap,
      rootGoalIds: goalIds,
      hoverActionsBuilder: (goalId) => HoverActionsWidget(
        goalId: goalId,
        goalMap: widget.goalMap,
      ),
      depthLimit: _mode == GoalViewMode.list ? 1 : null,
      showAddGoal: false,
    );
  }

  Widget _listView(WorldContext worldContext) {
    final theme = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final manualTimeSlices = ref.watch(manualTimeSliceProvider);
    final createTimeSliceOptions = this._computeCreateTimeSliceOptions(
        worldContext,
        [
          TimeSlice.today,
          TimeSlice.this_week,
          TimeSlice.this_month,
          TimeSlice.this_quarter,
          TimeSlice.this_year,
          TimeSlice.long_term,
        ],
        manualTimeSlices.value ?? []);

    return Column(
      key: const ValueKey('list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                if (_filter == GoalFilter.schedule_v2)
                  Tooltip(
                    waitDuration: Duration(milliseconds: 200),
                    showDuration: Duration.zero,
                    message: 'Add a Time Slice',
                    child: MenuAnchor(
                      controller: this._addTimeSliceMenuController,
                      menuChildren: [
                        ...createTimeSliceOptions.map((slice) => MenuItemButton(
                              child: Text(slice.displayName),
                              onPressed: () => createManualTimeSlice(slice),
                            )),
                      ],
                      child: GlassGoalsIconButton(
                          enabled: createTimeSliceOptions.isNotEmpty,
                          iconWidget: const Icon(Icons.add),
                          onPressed: () {
                            this._addTimeSliceMenuController.open();
                          }),
                    ),
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
                        return FlattenedGoalTree(
                          section: 'all-goals',
                          goalMap: goalMap,
                          rootGoalIds: goalIds,
                          hoverActionsBuilder: (goalId) => HoverActionsWidget(
                            goalId: goalId,
                            goalMap: widget.goalMap,
                          ),
                          depthLimit: _mode == GoalViewMode.list ? 1 : null,
                        );
                      case GoalFilter.to_review:
                        final toReview = {
                          'Orphaned Goals': _orphanedGoals(worldContext),
                          'Previously Active Goals':
                              _previouslyActiveGoals(worldContext),
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
                        return FlattenedGoalTree(
                          section: 'pending',
                          goalMap: goalMap,
                          rootGoalIds: goalIds,
                          hoverActionsBuilder: (goalId) => HoverActionsWidget(
                              goalId: goalId, goalMap: widget.goalMap),
                          depthLimit: _mode == GoalViewMode.list ? 1 : null,
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
                                  Container(),
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _timeSlices(worldContext, [
                            TimeSlice.today,
                            TimeSlice.this_week,
                            TimeSlice.this_month,
                            TimeSlice.this_quarter,
                            TimeSlice.this_year,
                            TimeSlice.long_term
                          ]),
                        );
                      case GoalFilter.schedule_v2:
                        return ScheduledGoalsV2(goalMap: goalMap);
                    }
                  })),
        ),
      ],
    );
  }

  Widget _detailView() {
    final focusedGoalId =
        ref.watch(focusedGoalProvider).value ?? focusedGoalStream.value;
    final focusedGoal = widget.goalMap[focusedGoalId];
    if (focusedGoal == null) {
      return Container(
          key: const ValueKey('detail'),
          child: const Text('No child with that id found.'));
    }

    return SingleChildScrollView(
      key: const ValueKey('detail'),
      child: GoalDetail(
        goal: focusedGoal,
        goalMap: widget.goalMap,
        onExpanded: this._onExpanded,
        onFocused: this._onFocused,
        onSelected: this._onSelected,
        onAddGoal: this._onAddGoal,
        onDropGoal: this._onDropGoal,
        hoverActionsBuilder: (goalId) =>
            HoverActionsWidget(goalId: goalId, goalMap: widget.goalMap),
      ),
    );
  }
}
