import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal, WorldContext, getGoalStatus;
import 'package:goals_core/sync.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_context.dart';
import '../styles.dart';
import 'providers.dart'
    show expandedGoalsProvider, selectedGoalsProvider, worldContextProvider;

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

Color getGoalStatusColor(WorldContext context, Goal goal) {
  final status = getGoalStatus(context, goal);
  switch (status.status) {
    case GoalStatus.active:
      return Colors.green;
    case GoalStatus.done:
      return Colors.blueGrey;
    case GoalStatus.archived:
      return Colors.grey;
    case GoalStatus.pending:
      return Colors.amber;
    case null:
      return Colors.deepPurple;
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

  @override
  Widget build(BuildContext context) {
    final isExpanded =
        ref.watch(expandedGoalsProvider).contains(widget.goal.id);
    final isSelected =
        ref.watch(selectedGoalsProvider).contains(widget.goal.id);
    final worldContext = ref.watch(worldContextProvider);
    return MouseRegion(
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
      child: Container(
        color: widget.hovered ? Colors.grey.shade300 : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Checkbox(
                value: isSelected,
                onChanged: widget.onSelected,
                visualDensity: VisualDensity.standard),
            _editing
                ? IntrinsicWidth(
                    child: TextField(
                      autocorrect: false,
                      controller: _textController,
                      decoration: null,
                      style: mainTextStyle,
                      onEditingComplete: () {
                        AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                            id: widget.goal.id, text: _textController!.text));
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
                : GestureDetector(
                    onDoubleTap: () => {
                      setState(() {
                        _editing = true;
                        _focusNode.requestFocus();
                      })
                    },
                    onTap: () {
                      widget.onFocused?.call(widget.goal.id);
                    },
                    child: Text(
                        '${widget.parent == null ? '' : '${widget.parent!.text} ❯ '}${widget.goal.text}',
                        style: mainTextStyle.copyWith(
                            fontWeight: widget.focused
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
            SizedBox(width: uiUnit(2)),
            // chip like container widget around text status widget:
            Container(
              decoration: BoxDecoration(
                color: getGoalStatusColor(worldContext, widget.goal),
                borderRadius: BorderRadius.circular(10000.0),
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: uiUnit(2), vertical: uiUnit()),
              child: Text(
                getGoalStatusString(worldContext, widget.goal),
                style: smallTextStyle.copyWith(color: Colors.white),
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
            (isSelected || _hovering) ? widget.hoverActions : Container(),
          ],
        ),
      ),
    );
  }
}
