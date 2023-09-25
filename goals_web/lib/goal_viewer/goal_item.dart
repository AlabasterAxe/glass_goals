import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal, WorldContext, getGoalStatus;
import 'package:goals_core/sync.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_context.dart';
import '../styles.dart';

class GoalItemWidget extends StatefulWidget {
  final Goal goal;
  final bool selected;
  final Function(bool? value) onSelected;
  final bool hovered;
  final bool focused;
  final Goal? parent;
  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.selected,
    required this.onSelected,
    required this.hovered,
    this.focused = false,
    this.parent,
  });

  @override
  State<GoalItemWidget> createState() => _GoalItemWidgetState();
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

String getGoalStatusString(Goal goal) {
  final worldContext = WorldContext.now();
  final status = getGoalStatus(worldContext, goal);
  switch (status?.status) {
    case GoalStatus.active:
      return 'Active: ${getRelativeDateString(worldContext.time, status!.endTime)}';
    case GoalStatus.done:
      return 'Done';
    case GoalStatus.archived:
      return 'Archived';
    case GoalStatus.pending:
      return 'On Hold: ${getRelativeDateString(worldContext.time, status!.endTime)}';
    case null:
      return 'No status';
  }
}

Color getGoalStatusColor(Goal goal) {
  final status = getGoalStatus(WorldContext.now(), goal);
  switch (status?.status) {
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

class _GoalItemWidgetState extends State<GoalItemWidget> {
  TextEditingController? _textController;
  bool _editing = false;
  final FocusNode _focusNode = FocusNode();

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
    return Container(
      color: widget.hovered ? Colors.grey.shade300 : Colors.transparent,
      child: Row(
        children: [
          Checkbox(value: widget.selected, onChanged: widget.onSelected),
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
                  child: Text(
                      '${widget.parent == null ? '' : '${widget.parent!.text} ❯ '}${widget.goal.text}',
                      style: mainTextStyle),
                ),
          const SizedBox(width: 4),
          // chip like container widget around text status widget:
          Container(
            decoration: BoxDecoration(
              color: getGoalStatusColor(widget.goal),
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Text(
              getGoalStatusString(widget.goal),
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}
