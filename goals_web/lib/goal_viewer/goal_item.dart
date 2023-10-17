import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal, WorldContext, getGoalStatus;
import 'package:goals_core/sync.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_context.dart';
import '../styles.dart';
import 'providers.dart'
    show expandedGoalsProvider, selectedGoalsProvider, worldContextProvider;

enum GoalItemDragHandle {
  none,
  bullet,
  item,
}

class GoalItemWidget extends StatefulHookConsumerWidget {
  final Goal goal;
  final Function(bool? value) onSelected;
  final Function(String id, {bool expanded}) onExpanded;
  final Function(String id)? onFocused;

  final bool hovered;
  final bool focused;
  final Goal? parent;
  final Widget hoverActions;
  final bool hasRenderableChildren;
  final GoalItemDragHandle dragHandle;
  final Function()? onDragEnd;
  final Function()? onDragStarted;

  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.onSelected,
    required this.onExpanded,
    required this.onFocused,
    required this.hovered,
    this.focused = false,
    this.parent,
    required this.hoverActions,
    required this.hasRenderableChildren,
    this.dragHandle = GoalItemDragHandle.none,
    this.onDragEnd,
    this.onDragStarted,
  });

  @override
  ConsumerState<GoalItemWidget> createState() => _GoalItemWidgetState();
}

String getRelativeDateString(DateTime now, DateTime? future) {
  if (future == null) {
    return 'Forever';
  }

  if (now.year != future.year) {
    return DateFormat.yMd().format(future);
  }

  if (future.difference(now).inDays > 7) {
    return DateFormat.Md().format(future);
  }

  if (future.difference(now).inDays > 1) {
    return DateFormat.E().format(future);
  }

  if (future.difference(now).inDays == 1) {
    return 'Tomorrow';
  }

  return 'Today';
}

String getGoalStatusString(WorldContext context, Goal goal) {
  final status = getGoalStatus(context, goal);
  switch (status.status) {
    case GoalStatus.active:
      return 'Active: ${getRelativeDateString(context.time, status.endTime)}';
    case GoalStatus.done:
      return 'Done';
    case GoalStatus.archived:
      return 'Archived';
    case GoalStatus.pending:
      return 'On Hold: ${getRelativeDateString(context.time, status.endTime)}';
    case null:
      return 'No status';
  }
}

Color getGoalStatusBackgroundColor(WorldContext context, Goal goal) {
  final status = getGoalStatus(context, goal);
  switch (status.status) {
    case GoalStatus.active:
      return paleGreenColor;
    case GoalStatus.done:
      return paleBlueColor;
    case GoalStatus.archived:
      return paleGreyColor;
    case GoalStatus.pending:
      return yellowColor;
    case null:
      return palePurpleColor;
  }
}

Color getGoalStatusTextColor(WorldContext context, Goal goal) {
  final status = getGoalStatus(context, goal);
  switch (status.status) {
    case GoalStatus.active:
      return darkGreenColor;
    case GoalStatus.done:
      return darkBlueColor;
    case GoalStatus.archived:
      return darkGreyColor;
    case GoalStatus.pending:
      return darkBrownColor;
    case null:
      return darkPurpleColor;
  }
}

class _GoalItemWidgetState extends ConsumerState<GoalItemWidget> {
  TextEditingController? _textController;
  bool _editing = false;
  final FocusNode _focusNode = FocusNode();
  bool _hovering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: widget.goal.text);
    } else {
      _textController!.text = widget.goal.text;
    }
  }

  Widget _dragWrapWidget(
      {required Widget child,
      required bool isSelected,
      required Set<String> selectedGoals}) {
    return Draggable<String>(
      data: widget.goal.id,
      onDragEnd: (_) => widget.onDragEnd?.call(),
      onDragStarted: widget.onDragStarted,
      feedback: Container(
        decoration:
            const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
              (isSelected ? selectedGoals.length : selectedGoals.length + 1)
                  .toString(),
              style: const TextStyle(
                  fontSize: 20,
                  decoration: TextDecoration.none,
                  color: Colors.white)),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded =
        ref.watch(expandedGoalsProvider).contains(widget.goal.id);
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final isSelected = selectedGoals.contains(widget.goal.id);
    final worldContext = ref.watch(worldContextProvider);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final bullet = SizedBox(
      width: uiUnit(10),
      height: uiUnit(10),
      child: Center(
          child: Container(
        width: uiUnit(),
        height: uiUnit(),
        decoration: BoxDecoration(
          color: darkElementColor,
          borderRadius: BorderRadius.circular(uiUnit()),
        ),
      )),
    );
    final content = MouseRegion(
      onHover: (event) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (event) {
        setState(() {
          _hovering = false;
        });
      },
      child: GestureDetector(
        onDoubleTap: _editing
            ? null
            : () => {
                  setState(() {
                    _editing = true;
                    _focusNode.requestFocus();
                  })
                },
        onTap: _editing
            ? null
            : () {
                widget.onFocused?.call(widget.goal.id);
              },
        child: Container(
          decoration: BoxDecoration(
            color: widget.hovered || _hovering
                ? emphasizedLightBackground
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              widget.dragHandle == GoalItemDragHandle.bullet
                  ? _dragWrapWidget(
                      child: bullet,
                      isSelected: isSelected,
                      selectedGoals: selectedGoals)
                  : bullet,
              _editing
                  ? IntrinsicWidth(
                      child: TextField(
                        autocorrect: false,
                        controller: _textController,
                        decoration: null,
                        style: mainTextStyle,
                        onEditingComplete: () {
                          AppContext.of(context).syncClient.modifyGoal(
                              GoalDelta(
                                  id: widget.goal.id,
                                  text: _textController!.text));
                          setState(() {
                            _editing = false;
                          });
                        },
                        onTapOutside: (_) {
                          setState(() {
                            _editing = false;
                          });
                        },
                        focusNode: _focusNode,
                      ),
                    )
                  : Text(
                      '${widget.parent == null ? '' : '${widget.parent!.text} ❯ '}${widget.goal.text}',
                      style: mainTextStyle.copyWith(
                        fontWeight: widget.focused
                            ? FontWeight.bold
                            : FontWeight.normal,
                        decoration:
                            isSelected ? TextDecoration.underline : null,
                      )),
              SizedBox(width: uiUnit(2)),
              // chip like container widget around text status widget:
              Container(
                decoration: BoxDecoration(
                  color:
                      getGoalStatusBackgroundColor(worldContext, widget.goal),
                  borderRadius: BorderRadius.circular(1),
                ),
                padding: EdgeInsets.symmetric(
                    vertical: uiUnit() / 2, horizontal: uiUnit()),
                child: Text(
                  getGoalStatusString(worldContext, widget.goal),
                  style: smallTextStyle.copyWith(
                      color: getGoalStatusTextColor(worldContext, widget.goal)),
                ),
              ),
              IconButton(
                  onPressed: () => widget.onExpanded(widget.goal.id),
                  icon: Icon(isExpanded
                      ? Icons.arrow_drop_down
                      : widget.hasRenderableChildren
                          ? Icons.arrow_right
                          : Icons.add)),
              const Spacer(),
              isSelected && !isNarrow ? widget.hoverActions : Container(),
            ],
          ),
        ),
      ),
    );
    return widget.dragHandle == GoalItemDragHandle.item
        ? _dragWrapWidget(
            isSelected: isSelected,
            selectedGoals: selectedGoals,
            child: content,
          )
        : content;
  }
}
