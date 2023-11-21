import 'package:flutter/rendering.dart'
    show Clip, CrossAxisAlignment, HitTestBehavior;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        DragTarget,
        Expanded,
        MediaQuery,
        Positioned,
        Row,
        SizedBox,
        Stack,
        Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../styles.dart' show darkElementColor, uiUnit;
import 'goal_item.dart' show GoalItemDragHandle, GoalItemWidget;
import 'goal_list.dart';

class GoalTreeWidget extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  final Function(String goalId) onSelected;
  final Function(String goalId)? onFocused;
  final Function(String goalId, {bool? expanded}) onExpanded;
  final Function(String?, String)? onAddGoal;
  final int? depthLimit;
  final bool showParentName;
  final HoverActionsBuilder hoverActionsBuilder;
  const GoalTreeWidget({
    super.key,
    required this.goalMap,
    required this.rootGoalId,
    required this.onSelected,
    required this.onExpanded,
    this.onFocused,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    required this.onAddGoal,
  });

  @override
  ConsumerState<GoalTreeWidget> createState() => _GoalTreeWidgetState();
}

class _GoalTreeWidgetState extends ConsumerState<GoalTreeWidget> {
  bool hovered = false;
  bool hoverTop = false;
  bool dragging = false;

  moveGoals(String newParentId, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];
    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: SetParentLogEntry(
              id: Uuid().v4(),
              parentId: newParentId,
              creationTime: DateTime.now())));
    }
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  @override
  Widget build(BuildContext context) {
    final Goal rootGoal = widget.goalMap[widget.rootGoalId]!;
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final isExpanded = ref.watch(expandedGoalsProvider).contains(rootGoal.id);
    final hasRenderableChildren = widget.goalMap[widget.rootGoalId]!.subGoals
        .any((element) => widget.goalMap.containsKey(element.id));
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: uiUnit(10),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: DragTarget<String>(
                onAccept: (droppedGoalId) {
                  final selectedAndDraggedGoals = {
                    ...selectedGoals,
                    droppedGoalId
                  };
                  moveGoals(
                      rootGoal.id,
                      selectedGoals.contains(droppedGoalId)
                          ? selectedAndDraggedGoals
                          : {droppedGoalId});
                  ref.read(selectedGoalsProvider.notifier).clear();
                },
                onMove: (_) {
                  setState(() {
                    hovered = true;
                  });
                },
                onLeave: (_) {
                  setState(() {
                    hovered = false;
                  });
                },
                builder: (context, _, __) => GoalItemWidget(
                  goal: rootGoal,
                  onDragEnd: () {
                    setState(() {
                      hovered = false;
                      dragging = false;
                    });
                  },
                  onDragStarted: () {
                    setState(() {
                      dragging = true;
                    });
                  },
                  onFocused: widget.onFocused,
                  hovered: hovered && !dragging,
                  hoverActionsBuilder: widget.hoverActionsBuilder,
                  hasRenderableChildren: hasRenderableChildren,
                  onExpanded: widget.onExpanded,
                  dragHandle: isNarrow
                      ? GoalItemDragHandle.bullet
                      : GoalItemDragHandle.item,
                ),
              ),
            ),
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: uiUnit(2),
                child: DragTarget<String>(
                  hitTestBehavior: HitTestBehavior.opaque,
                  onAccept: (droppedGoalId) {
                    setState(() {
                      hoverTop = false;
                    });

                    print('drop on top border!');
                  },
                  onMove: (_) {
                    setState(() {
                      hoverTop = true;
                    });
                  },
                  onLeave: (_) {
                    setState(() {
                      hoverTop = false;
                    });
                  },
                  builder: (context, _, __) => Container(),
                )),
            if (hoverTop)
              Positioned(
                  top: -1,
                  height: 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: darkElementColor,
                  )),
          ]),
        ),
        isExpanded && (widget.depthLimit == null || widget.depthLimit! > 0)
            ? Row(children: [
                SizedBox(width: uiUnit(5)),
                Expanded(
                    child: GoalListWidget(
                  goalMap: widget.goalMap,
                  goalIds: rootGoal.subGoals
                      .where((g) => widget.goalMap.containsKey(g.id))
                      .map((e) => e.id)
                      .toList(),
                  onSelected: widget.onSelected,
                  onExpanded: widget.onExpanded,
                  onFocused: widget.onFocused,
                  depthLimit:
                      widget.depthLimit == null ? null : widget.depthLimit! - 1,
                  hoverActionsBuilder: widget.hoverActionsBuilder,
                  onAddGoal: widget.onAddGoal,
                )),
              ])
            : Container()
      ],
    );
  }
}
