import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';

import '../app_context.dart';
import '../styles.dart';

class GoalItemWidget extends StatefulWidget {
  final Goal goal;
  final bool selected;
  final Function(bool? value) onSelected;
  const GoalItemWidget(
      {super.key,
      required this.goal,
      required this.selected,
      required this.onSelected});

  @override
  State<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends State<GoalItemWidget> {
  TextEditingController? _textController;
  bool _editing = false;
  FocusNode _focusNode = FocusNode();

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
    return Row(
      children: [
        Checkbox(value: widget.selected, onChanged: widget.onSelected),
        _editing
            ? SizedBox(
                width: 200,
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
                ))
            : GestureDetector(
                onDoubleTap: () => {
                  setState(() {
                    _editing = true;
                    _focusNode.requestFocus();
                  })
                },
                child: Text(widget.goal.text, style: mainTextStyle),
              ),
      ],
    );
  }
}
