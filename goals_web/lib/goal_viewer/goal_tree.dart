import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxDecoration, CrossAxisAlignment, EdgeInsets;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        Draggable,
        GestureDetector,
        Row,
        SingleChildScrollView,
        SizedBox,
        Spacer,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';
import '../app_context.dart';
import 'goal_item.dart' show GoalItemWidget;

class GoalTreeWidget extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  final Set<String> selectedGoals;
  final Set<String> expandedGoals;
  final Function(String goalId) onSelected;
  final Function(String goalId) onExpanded;
  final int? depthLimit;
  const GoalTreeWidget({
    super.key,
    required this.goalMap,
    required this.rootGoalId,
    required this.selectedGoals,
    required this.onSelected,
    required this.expandedGoals,
    required this.onExpanded,
    this.depthLimit,
  });

  @override
  State<GoalTreeWidget> createState() => _GoalTreeWidgetState();
}

class _GoalTreeWidgetState extends State<GoalTreeWidget> {
  moveGoals(String newParentId, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];
    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(id: goalId, parentId: newParentId));
    }
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  @override
  Widget build(BuildContext context) {
    final Goal rootGoal = widget.goalMap[widget.rootGoalId]!;
    return GestureDetector(
      onTap: () => widget.onExpanded(rootGoal.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DragTarget<String>(
            onAccept: (droppedGoalId) {
              final selectedAndDraggedGoals = {
                ...widget.selectedGoals,
                droppedGoalId
              };
              moveGoals(rootGoal.id, selectedAndDraggedGoals);
            },
            builder: (context, _, __) => Draggable<String>(
              data: rootGoal.id,
              feedback: Container(
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      (widget.selectedGoals.contains(rootGoal.id)
                              ? widget.selectedGoals.length
                              : widget.selectedGoals.length + 1)
                          .toString(),
                      style: const TextStyle(
                          fontSize: 20,
                          decoration: TextDecoration.none,
                          color: Colors.white)),
                ),
              ),
              child: GoalItemWidget(
                  goal: rootGoal,
                  selected: widget.selectedGoals.contains(rootGoal.id),
                  onSelected: (value) {
                    widget.onSelected(rootGoal.id);
                  }),
            ),
          ),
          widget.expandedGoals.contains(rootGoal.id) &&
                  (widget.depthLimit == null || widget.depthLimit! > 0)
              ? Row(children: [
                  const SizedBox(width: 20),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final subGoal in rootGoal.subGoals)
                          GoalTreeWidget(
                            goalMap: widget.goalMap,
                            rootGoalId: subGoal.id,
                            onSelected: widget.onSelected,
                            selectedGoals: widget.selectedGoals,
                            expandedGoals: widget.expandedGoals,
                            onExpanded: widget.onExpanded,
                            depthLimit: widget.depthLimit == null
                                ? null
                                : widget.depthLimit! - 1,
                          ),
                      ])
                ])
              : Container()
        ],
      ),
    );
  }
}
