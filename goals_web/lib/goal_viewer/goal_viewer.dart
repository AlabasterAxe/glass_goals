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
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getGoalPriority,
        getGoalsForDateRange,
        getGoalsMatchingPredicate,
        getTransitiveSubGoals,
        isAnchor;
import 'package:goals_core/sync.dart'
    show
        AddParentLogEntry,
        ClearAnchorLogEntry,
        GoalDelta,
        GoalStatus,
        MakeAnchorLogEntry,
        PriorityLogEntry,
        RemoveParentLogEntry,
        SetParentLogEntry,
        SetSummaryEntry,
        StatusLogEntry;
import 'package:goals_web/app_bar.dart';
import 'package:goals_web/app_context.dart';
import 'package:goals_web/common/os_utils.dart';
import 'package:goals_web/goal_viewer/debug_panel.dart';
import 'package:goals_web/goal_viewer/flattened_goal_tree.dart';
import 'package:goals_web/goal_viewer/goal_detail.dart';
import 'package:goals_web/goal_viewer/pending_goal_viewer.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/scheduled_goals_v2.dart';
import 'package:goals_web/intents.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../common/keyboard_utils.dart';
import '../common/time_slice.dart';
import '../styles.dart' show lightBackground, multiSplitViewThemeData, uiUnit;
import '../widgets/gg_icon_button.dart';
import 'goal_actions_context.dart';
import 'goal_search_modal.dart';
import 'goal_viewer_constants.dart';
import 'hover_actions.dart';

class GoalViewer extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  const GoalViewer({super.key, required this.goalMap});

  @override
  ConsumerState<GoalViewer> createState() => _GoalViewerState();
}

enum GoalFilterType {
  all(displayName: "All Goals"),
  schedule_v2(displayName: "Scheduled Goals"),
  pending_v2(displayName: "Pending Goals");

  const GoalFilterType({required this.displayName});

  final String displayName;
}

enum GoalViewMode { tree, list, schedule }

sealed class GoalFilter {
  get displayName;
}

class PredefinedGoalFilter extends GoalFilter {
  final GoalFilterType type;
  PredefinedGoalFilter(this.type);
  get displayName => type.displayName;
}

class GoalGoalFilter extends GoalFilter {
  final String goalId;
  final Map<String, Goal> goalMap;
  GoalGoalFilter(
    this.goalId,
    this.goalMap,
  );
  get displayName => this.goalMap[this.goalId]?.text ?? 'Untitled';
}

class _GoalViewerState extends ConsumerState<GoalViewer> {
  GoalFilter _filter = PredefinedGoalFilter(GoalFilterType.pending_v2);
  GoalViewMode _mode = GoalViewMode.tree;
  final FocusNode _focusNode = FocusNode();

  List<GoalGoalFilter> _goalFilters = [];

  Future<void>? openBoxFuture;
  bool isInitted = false;
  late MultiSplitViewController _multiSplitViewController =
      this._getMultiSplitViewController(ref.read(debugProvider));
  PendingGoalViewMode _pendingGoalViewMode = PendingGoalViewMode.schedule;

  final _addTimeSliceMenuController = MenuController();

  bool _debugDebounce = false;

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
    // TODO: fix this
    if (filter is PredefinedGoalFilter) {
      Hive.box('goals_web.ui').put('goalViewerFilter', filter.type.name);
    }
  }

  _onExpanded(String goalId, {bool? expanded}) {
    setState(() {
      if (expanded != null) {
        if (expanded) {
          addId(expandedGoalsStream, goalId);
        } else {
          removeId(expandedGoalsStream, goalId);
        }
      } else {
        toggleId(expandedGoalsStream, goalId);
      }
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

      if (!isCtrlHeld()) {
        focusedGoalStream.add(goalId);
      }
      Hive.box('goals_web.ui').put('focusedGoal', goalId);
    });
  }

  _onAddGoal(String? parentId, String text, [TimeSlice? timeSlice]) {
    final goalDeltas = <GoalDelta>[];

    if (parentId != null) {
      goalDeltas.add(GoalDelta(
          id: const Uuid().v4(),
          text: text,
          logEntry: SetParentLogEntry(
              id: const Uuid().v4(),
              creationTime: DateTime.now(),
              parentId: parentId)));
    } else {
      goalDeltas.add(GoalDelta(
        id: const Uuid().v4(),
        text: text,
      ));
    }

    if (timeSlice != null && timeSlice != TimeSlice.unscheduled) {
      goalDeltas.add(GoalDelta(
          id: const Uuid().v4(),
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

  @override
  didUpdateWidget(GoalViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalMap != widget.goalMap) {
      setState(() {
        _goalFilters = getGoalsMatchingPredicate(
                widget.goalMap, (g) => isAnchor(g) != null)
            .entries
            .map((e) => GoalGoalFilter(e.key, widget.goalMap))
            .toList();
      });
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
                defaultValue: GoalFilterType.schedule_v2.name);

            try {
              _filter = PredefinedGoalFilter(
                  GoalFilterType.values.byName(filterString));
            } catch (_) {
              _filter = PredefinedGoalFilter(GoalFilterType.schedule_v2);
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

    _goalFilters =
        getGoalsMatchingPredicate(widget.goalMap, (g) => isAnchor(g) != null)
            .entries
            .map((e) => GoalGoalFilter(e.key, widget.goalMap))
            .toList();
  }

  _toggleDebug() {
    if (this._debugDebounce) {
      return;
    }
    this._debugDebounce = true;
    ref.read(debugProvider.notifier).toggle();
    Future.delayed(const Duration(milliseconds: 200), () {
      this._debugDebounce = false;
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
      PredefinedGoalFilter(GoalFilterType.pending_v2),
      PredefinedGoalFilter(GoalFilterType.all),
      ..._goalFilters,
    ];

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

  List<GoalDelta> _computeDropOnSeparatorEffects(
      Set<GoalDragDetails> draggedGoalDetails,
      List<String> prevGoalPath,
      List<String> nextGoalPath) {
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

    for (final details in draggedGoalDetails) {
      final droppedGoal = this.widget.goalMap[details.goalId];
      if (newParentId != null &&
          droppedGoal != null &&
          !droppedGoal.hasParent(newParentId)) {
        final pathParentId =
            details.sourcePath != null && details.sourcePath!.length > 1
                ? details.sourcePath![details.sourcePath!.length - 2]
                : null;
        final pathParent =
            pathParentId == null ? null : this.widget.goalMap[pathParentId];
        if (pathParent == null) {
          // if the source path is not provided or the parent is not found, do the legacy behavior of setting the parent to the exclusion of any prior parents.
          goalDeltas.add(GoalDelta(
              id: details.goalId,
              logEntry: SetParentLogEntry(
                  id: Uuid().v4(),
                  parentId: newParentId,
                  creationTime: DateTime.now())));
          continue;
        }

        goalDeltas.add(GoalDelta(
            id: details.goalId,
            logEntry: RemoveParentLogEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              parentId: pathParentId,
            )));
        goalDeltas.add(GoalDelta(
            id: details.goalId,
            logEntry: AddParentLogEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              parentId: newParentId,
            )));
      }

      goalDeltas.add(GoalDelta(
          id: details.goalId,
          logEntry: PriorityLogEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              priority: newPriority)));
    }

    return goalDeltas;
  }

  List<GoalDelta> _computeDropOnGoalEffects(
      Set<GoalDragDetails> draggedGoalDetails, List<String> targetGoalPath) {
    final List<GoalDelta> goalDeltas = [];
    for (final details in draggedGoalDetails) {
      final droppedGoal = this.widget.goalMap[details.goalId];

      if (droppedGoal == null || droppedGoal.hasParent(details.goalId)) {
        continue;
      }

      final pathParentId =
          details.sourcePath != null && details.sourcePath!.length > 1
              ? details.sourcePath![details.sourcePath!.length - 2]
              : null;
      final pathParent =
          pathParentId == null ? null : this.widget.goalMap[pathParentId];
      if (pathParent == null) {
        // if the source path is not provided or the parent is not found, do the legacy behavior of setting the parent to the exclusion of any prior parents.
        goalDeltas.add(GoalDelta(
            id: details.goalId,
            logEntry: SetParentLogEntry(
                id: Uuid().v4(),
                parentId: targetGoalPath.lastOrNull,
                creationTime: DateTime.now())));
        continue;
      }

      goalDeltas.add(GoalDelta(
          id: details.goalId,
          logEntry: RemoveParentLogEntry(
            id: Uuid().v4(),
            creationTime: DateTime.now(),
            parentId: pathParentId,
          )));
      goalDeltas.add(GoalDelta(
          id: details.goalId,
          logEntry: AddParentLogEntry(
            id: Uuid().v4(),
            creationTime: DateTime.now(),
            parentId: targetGoalPath.lastOrNull,
          )));
    }
    return goalDeltas;
  }

  List<GoalDelta> _computeDropGoalEffects(
    String droppedGoalId, {
    List<String>? sourcePath,
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) {
    // TODO: update selected goals to include the full path
    final selectedGoals = selectedGoalsStream.value;
    Set<GoalDragDetails> goalsToUpdate = selectedGoals.contains(droppedGoalId)
        ? {
            ...selectedGoals.map(
              (e) {
                if (e == droppedGoalId) {
                  return GoalDragDetails(goalId: e, sourcePath: sourcePath);
                }
                return GoalDragDetails(goalId: e);
              },
            )
          }
        : {GoalDragDetails(goalId: droppedGoalId, sourcePath: sourcePath)};

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
    List<String>? sourcePath,
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) {
    final goalDeltas = _computeDropGoalEffects(
      droppedGoalId,
      sourcePath: sourcePath,
      dropPath: dropPath,
      prevDropPath: prevDropPath,
      nextDropPath: nextDropPath,
    );
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
    selectedGoalsStream.add({});
  }

  _onMakeAnchor(String goalId) {
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: goalId,
        logEntry:
            MakeAnchorLogEntry(id: Uuid().v4(), creationTime: DateTime.now())));
  }

  _onClearAnchor(String goalId) {
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: goalId,
        logEntry: ClearAnchorLogEntry(
            id: Uuid().v4(), creationTime: DateTime.now())));
  }

  _onAddSummary(String goalId) {
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: goalId,
        logEntry: SetSummaryEntry(
            id: Uuid().v4(),
            text: "[Your Summary Here]",
            creationTime: DateTime.now())));
  }

  _onClearSummary(String goalId) {
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: goalId,
        logEntry: SetSummaryEntry(
            id: Uuid().v4(), text: null, creationTime: DateTime.now())));
  }

  @override
  Widget build(BuildContext context) {
    final focusedGoalId =
        ref.watch(focusedGoalProvider).value ?? focusedGoalStream.value;
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final isDebug = ref.watch(debugProvider);
    ref.listen(focusedGoalProvider, _handleFocusedGoalChange);
    ref.listen(debugProvider, (_, isDebug) {
      setState(() {
        _multiSplitViewController = _getMultiSplitViewController(isDebug);
      });
    });

    final children = <Widget>[];

    final singleScreen = MediaQuery.of(context).size.width < 600;
    final showHamburger = MediaQuery.of(context).size.width < 1000;
    if (!showHamburger) {
      children.add(_viewSwitcher(false, worldContext, isDebug));
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

    if (!singleScreen && isDebug)
      children.add(DebugPanel(
        key: const ValueKey('debug'),
      ));

    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      behavior: HitTestBehavior.opaque,
      child: GoalActionsContext(
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
        onClearAnchor: this._onClearAnchor,
        onMakeAnchor: this._onMakeAnchor,
        onAddSummary: this._onAddSummary,
        onClearSummary: this._onClearSummary,
        child: FocusableActionDetector(
          autofocus: true,
          shortcuts: isMacOS() ? MAC_SHORTCUTS : SHORTCUTS,
          actions: {
            SearchIntent: CallbackAction(onInvoke: _openSearch),
            UndoIntent: CallbackAction(onInvoke: (_) {
              AppContext.of(context).syncClient.undo();
            }),
            RedoIntent: CallbackAction(onInvoke: (_) {
              AppContext.of(context).syncClient.redo();
            }),
            ToggleDebugModeIntent:
                CallbackAction(onInvoke: (_) => _toggleDebug()),
          },
          focusNode: _focusNode,
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
                      child: _viewSwitcher(true, worldContext, isDebug),
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
                  if (singleScreen && focusedGoalId != null)
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: uiUnit(16),
                        child: Container(
                          color: lightBackground,
                          child: HoverActionsWidget(
                            goalMap: widget.goalMap,
                            mainAxisSize: MainAxisSize.max,
                          ),
                        ))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _openSearch(_) async {
    await showDialog(
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
                      onGoalSelected: (focusedGoalId) {
                        focusedGoalStream.add(focusedGoalId);
                        return GoalSelectedResult.close;
                      })),
            ));
  }

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
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _filter.displayName,
                      style: theme.headlineMedium,
                    ),
                    if (_filter is PredefinedGoalFilter &&
                            (_filter as PredefinedGoalFilter).type ==
                                GoalFilterType.pending_v2 ||
                        _filter is GoalGoalFilter)
                      Tooltip(
                        waitDuration: Duration(milliseconds: 200),
                        showDuration: Duration.zero,
                        message: 'Add a Time Slice',
                        child: MenuAnchor(
                          controller: this._addTimeSliceMenuController,
                          menuChildren: [
                            ...createTimeSliceOptions
                                .map((slice) => MenuItemButton(
                                      child: Text(slice.displayName),
                                      onPressed: () =>
                                          createManualTimeSlice(slice),
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
                if (_filter is PredefinedGoalFilter &&
                        (_filter as PredefinedGoalFilter).type ==
                            GoalFilterType.pending_v2 ||
                    _filter is GoalGoalFilter)
                  PendingGoalViewModePicker(
                      onModeChanged: (mode) => this.setState(() {
                            _pendingGoalViewMode = mode;
                          }),
                      viewKey: "root")
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
                      case PredefinedGoalFilter filter:
                        switch (filter.type) {
                          case GoalFilterType.all:
                            final goalIds = _mode == GoalViewMode.tree
                                ? goalMap.values
                                    .where((goal) {
                                      for (final superGoalId
                                          in goal.superGoalIds) {
                                        if (goalMap.containsKey(superGoalId)) {
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
                              hoverActionsBuilder: (path) => HoverActionsWidget(
                                path: path,
                                goalMap: widget.goalMap,
                              ),
                              depthLimit: _mode == GoalViewMode.list ? 1 : null,
                            );
                          case GoalFilterType.schedule_v2:
                            return ScheduledGoalsV2(goalMap: goalMap);
                          case GoalFilterType.pending_v2:
                            return PendingGoalViewer(
                              goalMap: goalMap,
                              viewKey: 'root',
                              mode: this._pendingGoalViewMode,
                            );
                        }
                      case GoalGoalFilter filter:
                        return PendingGoalViewer(
                          path: [filter.goalId],
                          viewKey: '',
                          goalMap: getTransitiveSubGoals(goalMap, filter.goalId)
                            ..remove(filter.goalId),
                          mode: this._pendingGoalViewMode,
                        );
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
        hoverActionsBuilder: (path) =>
            HoverActionsWidget(path: path, goalMap: widget.goalMap),
      ),
    );
  }
}
