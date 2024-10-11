import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show
        Actions,
        BuildContext,
        CallbackAction,
        Column,
        Focus,
        FocusNode,
        KeyEventResult,
        Widget;
import 'package:goals_core/model.dart'
    show Goal, GoalPath, TraversalDecision, getPriorityComparator, traverseDown;
import 'package:goals_web/common/keyboard_utils.dart';
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:goals_web/intents.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import '../styles.dart';
import 'goal_actions_context.dart';
import 'goal_item.dart';
import 'goal_separator.dart';
import 'goal_viewer_constants.dart';
import 'providers.dart';
import 'package:collection/collection.dart' show IterableExtension;

typedef FlattenedGoalItem = ({
  GoalPath path,
  bool hasRenderableChildren,
});

class FlattenedGoalTree extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  final List<String> rootGoalIds;
  final int? depthLimit;
  final bool showParentName;
  final HoverActionsBuilder hoverActionsBuilder;
  final List<String> path;
  final bool showAddGoal;
  const FlattenedGoalTree({
    super.key,
    required this.goalMap,
    required this.rootGoalIds,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    this.showAddGoal = true,
    this.path = const [],
  });

  @override
  ConsumerState<FlattenedGoalTree> createState() => _FlattenedGoalTreeState();
}

class _FlattenedGoalTreeState extends ConsumerState<FlattenedGoalTree> {
  List<FlattenedGoalItem> _flattenedGoalItems = [];

  late StreamSubscription _hoverEventSubscription;

  int? _shiftHoverStartIndex;
  int? _shiftHoverEndIndex;

  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _updateShiftSelectionRange();
      }

      return KeyEventResult.ignored;
    },
  );

  _updateShiftSelectionRange() {
    if (!isShiftHeld()) {
      if ((_shiftHoverStartIndex != null || _shiftHoverEndIndex != null)) {
        setState(() {
          _shiftHoverStartIndex = null;
          _shiftHoverEndIndex = null;
        });
      }
      return;
    }

    if (textFocusStream.value != null) {
      return;
    }

    final lastSelectedGoalPath = selectedGoalsStream.value.lastOrNull;
    final hoveredPath = hoverEventStream.value;

    if (lastSelectedGoalPath != null && hoveredPath != null) {
      final lastSelectedGoalIndex = _flattenedGoalItems
          .indexWhere((item) => pathsMatch(item.path, lastSelectedGoalPath));
      final hoveredGoalIndex = _flattenedGoalItems
          .indexWhere((item) => pathsMatch(item.path, hoveredPath));
      if (lastSelectedGoalIndex != -1 &&
          hoveredGoalIndex != -1 &&
          lastSelectedGoalIndex != hoveredGoalIndex) {
        if (lastSelectedGoalIndex < hoveredGoalIndex &&
            (_shiftHoverStartIndex != lastSelectedGoalIndex ||
                _shiftHoverEndIndex != hoveredGoalIndex)) {
          setState(() {
            _shiftHoverStartIndex = lastSelectedGoalIndex;
            _shiftHoverEndIndex = hoveredGoalIndex;
          });
        } else if (lastSelectedGoalIndex > hoveredGoalIndex &&
            (_shiftHoverStartIndex != hoveredGoalIndex ||
                _shiftHoverEndIndex != lastSelectedGoalIndex)) {
          setState(() {
            _shiftHoverStartIndex = hoveredGoalIndex;
            _shiftHoverEndIndex = lastSelectedGoalIndex;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _updateFlattenedGoalItems();
    this._hoverEventSubscription = hoverEventStream.listen((_) {
      this._updateShiftSelectionRange();
    });
  }

  void _updateFlattenedGoalItems() {
    final context =
        ref.read(worldContextProvider).value ?? worldContextStream.value;
    final expandedGoalPaths =
        ref.read(expandedGoalsProvider).value ?? expandedGoalsStream.value;
    final textFocus =
        ref.read(textFocusProvider).value ?? textFocusStream.value;
    final priorityComparator = getPriorityComparator(context);
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final Goal goal in this
        .widget
        .rootGoalIds
        .map((id) => this.widget.goalMap[id])
        .where((goal) => goal != null)
        .cast<Goal>()
        .sorted(priorityComparator)) {
      traverseDown(
        this.widget.goalMap,
        goal.id,
        onVisit: (goalId, path) {
          final fullGoalPath = [...this.widget.path, ...path, goalId];
          flattenedGoals.add((
            path: GoalPath(fullGoalPath),
            hasRenderableChildren: this
                .widget
                .goalMap[goalId]!
                .subGoalIds
                .where((gId) => this.widget.goalMap.containsKey(gId))
                .isNotEmpty,
          ));

          if (expandedGoalPaths
                  .firstWhereOrNull((p) => pathsMatch(p, fullGoalPath)) ==
              null) {
            return TraversalDecision.dontRecurse;
          }
        },
        onDepart: (String goalId, List<String> path) {
          final addGoalPath = GoalPath(
              [...this.widget.path, ...path, goalId, NEW_GOAL_PLACEHOLDER]);
          if (this.widget.showAddGoal && pathsMatch(addGoalPath, textFocus)) {
            flattenedGoals.add((
              path: addGoalPath,
              hasRenderableChildren: false,
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.widget.showAddGoal) {
      flattenedGoals.add((
        path: GoalPath([...this.widget.path, NEW_GOAL_PLACEHOLDER]),
        hasRenderableChildren: false,
      ));
    }
    setState(() {
      _flattenedGoalItems = flattenedGoals;
    });
  }

  @override
  void didUpdateWidget(FlattenedGoalTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalMap != this.widget.goalMap ||
        oldWidget.rootGoalIds != this.widget.rootGoalIds ||
        oldWidget.path != this.widget.path) {
      _updateFlattenedGoalItems();
    }

    if (pathsMatch(this.widget.path, hoverEventStream.value)) {
      this._focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    this._hoverEventSubscription.cancel();
    this._focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expandedGoalsProvider, (_, __) => _updateFlattenedGoalItems());
    ref.listen(worldContextProvider, (_, __) => _updateFlattenedGoalItems());
    ref.listen(textFocusProvider, (_, __) => _updateFlattenedGoalItems());

    final hasMouse = ref.watch(hasMouseProvider);

    final goalItems = <Widget>[];
    final onDropGoal = GoalActionsContext.of(context).onDropGoal;
    final onArchive = GoalActionsContext.of(context).onArchive;

    for (int i = 0; i < this._flattenedGoalItems.length; i++) {
      final prevGoal = i > 0 ? this._flattenedGoalItems[i - 1] : null;
      final flattenedGoal = this._flattenedGoalItems[i];
      final goalId = flattenedGoal.path.goalId;
      goalItems.add(GoalSeparator(
          isFirst: i == 0,
          prevGoalPath: prevGoal?.path ?? [...this.widget.path],
          nextGoalPath: flattenedGoal.path,
          path: this.widget.path,
          goalMap: this.widget.goalMap,
          pendingShiftSelect: _shiftHoverStartIndex != null &&
              _shiftHoverEndIndex != null &&
              i >= _shiftHoverStartIndex! &&
              i <= _shiftHoverEndIndex!,
          shiftSelectStartPath: _shiftHoverStartIndex != null
              ? this._flattenedGoalItems[_shiftHoverStartIndex!].path
              : null,
          shiftSelectEndPath: _shiftHoverEndIndex != null
              ? this._flattenedGoalItems[_shiftHoverEndIndex!].path
              : null,
          onDropGoal: (goalDragDetails) {
            onDropGoal(goalDragDetails.path,
                prevDropPath: prevGoal?.path ?? [...this.widget.path],
                nextDropPath: flattenedGoal.path);
          }));
      goalItems.add(goalId != NEW_GOAL_PLACEHOLDER
          ? GoalItemWidget(
              onDropGoal: (details) {
                onDropGoal(
                  details.path,
                  dropPath: flattenedGoal.path,
                );
              },
              padding: EdgeInsets.only(
                  left: uiUnit(4) *
                      (flattenedGoal.path.length -
                          (1 + this.widget.path.length))),
              goal: this.widget.goalMap[goalId]!,
              pendingShiftSelect: _shiftHoverStartIndex != null &&
                  _shiftHoverEndIndex != null &&
                  i >= _shiftHoverStartIndex! &&
                  i <= _shiftHoverEndIndex!,
              hoverActionsBuilder: this.widget.hoverActionsBuilder,
              hasRenderableChildren: flattenedGoal.hasRenderableChildren,
              showExpansionArrow:
                  flattenedGoal.hasRenderableChildren || widget.showAddGoal,
              dragHandle: !hasMouse
                  ? GoalItemDragHandle.bullet
                  : GoalItemDragHandle.item,
              path: flattenedGoal.path,
            )
          : AddSubgoalItemWidget(
              path: flattenedGoal.path,
              padding: EdgeInsets.only(
                  left: uiUnit(4) *
                      (flattenedGoal.path.length -
                          (1 + this.widget.path.length))),
            ));
    }
    return Actions(
        actions: {
          if (textFocusStream.value == null)
            NextIntent: CallbackAction(
              onInvoke: (_) {
                final hoveredIndex = _flattenedGoalItems.indexWhere(
                    (item) => pathsMatch(item.path, hoverEventStream.value));
                if (hoveredIndex != -1 &&
                    hoveredIndex < _flattenedGoalItems.length - 1) {
                  hoverEventStream
                      .add(_flattenedGoalItems[hoveredIndex + 1].path);
                }
              },
            ),
          if (textFocusStream.value == null)
            PreviousIntent: CallbackAction(
              onInvoke: (_) {
                final hoveredIndex = _flattenedGoalItems.indexWhere(
                    (item) => pathsMatch(item.path, hoverEventStream.value));
                if (hoveredIndex != -1 && hoveredIndex > 0) {
                  hoverEventStream
                      .add(_flattenedGoalItems[hoveredIndex - 1].path);
                }
              },
            ),
          if (textFocusStream.value?.goalId == NEW_GOAL_PLACEHOLDER)
            IndentIntent: CallbackAction(
              onInvoke: (_) {
                final newGoalIndex = _flattenedGoalItems.indexWhere(
                    (item) => pathsMatch(item.path, textFocusStream.value));

                if (newGoalIndex > 0) {
                  final parentPath = _flattenedGoalItems[newGoalIndex - 1].path;
                  GoalActionsContext.of(context)
                      .onExpanded(parentPath, expanded: true);
                  final parentGoal = this.widget.goalMap[parentPath.goalId];
                  if (parentGoal != null) {
                    final newGoalPath =
                        GoalPath([...parentPath, NEW_GOAL_PLACEHOLDER]);
                    textFocusStream.add(newGoalPath);
                  }
                }
              },
            ),
          if (textFocusStream.value?.goalId == NEW_GOAL_PLACEHOLDER)
            OutdentIntent: CallbackAction(
              onInvoke: (_) {
                var newGoalIndex = _flattenedGoalItems.indexWhere(
                    (item) => pathsMatch(item.path, textFocusStream.value));

                GoalPath? parentPath;
                while (newGoalIndex > 0) {
                  newGoalIndex--;
                  final parentCandidate = _flattenedGoalItems[newGoalIndex];
                  if (textFocusStream.value!.length -
                          parentCandidate.path.length ==
                      2) {
                    parentPath = _flattenedGoalItems[newGoalIndex].path;
                    GoalActionsContext.of(context)
                        .onExpanded(parentPath, expanded: true);
                    final parentGoal = this.widget.goalMap[parentPath.goalId];
                    if (parentGoal != null) {
                      textFocusStream
                          .add(GoalPath([...parentPath, NEW_GOAL_PLACEHOLDER]));
                    }
                    return;
                  }
                }
                textFocusStream
                    .add(GoalPath([...this.widget.path, NEW_GOAL_PLACEHOLDER]));
              },
            ),
          if (textFocusStream.value == null)
            RemoveIntent: CallbackAction<RemoveIntent>(
              onInvoke: (_) {
                final index = _flattenedGoalItems.indexWhere(
                    (item) => pathsMatch(item.path, hoverEventStream.value));
                if (index == -1) return;
                if (index < _flattenedGoalItems.length - 1) {
                  hoverEventStream.add(_flattenedGoalItems[index - 1].path);
                } else {
                  hoverEventStream.add(null);
                }
                onArchive.call(_flattenedGoalItems[index].path.goalId);
              },
            ),
        },
        child: Focus(
          focusNode: this._focusNode,
          child: GoalActionsContext.overrideWith(context,
              onFocused: (this._shiftHoverEndIndex != null &&
                      this._shiftHoverEndIndex != null)
                  ? (goalId) {
                      final newSelectedGoals = [...selectedGoalsStream.value];
                      for (int i = this._shiftHoverStartIndex!;
                          i <= this._shiftHoverEndIndex!;
                          i++) {
                        final goalPath = _flattenedGoalItems[i].path;
                        if (goalPath.last != NEW_GOAL_PLACEHOLDER &&
                            !newSelectedGoals.contains(goalPath.last)) {
                          newSelectedGoals.add(goalPath);
                        }
                      }
                      selectedGoalsStream.add(newSelectedGoals);
                    }
                  : null,
              child: Column(children: goalItems)),
        ));
  }
}
