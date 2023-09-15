import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../app_context.dart';
import '../styles.dart';

class AddSubgoalItemWidget extends StatefulWidget {
  final String parentId;
  const AddSubgoalItemWidget({
    super.key,
    required this.parentId,
  });

  @override
  State<AddSubgoalItemWidget> createState() => _AddSubgoalItemWidgetState();
}

class _AddSubgoalItemWidgetState extends State<AddSubgoalItemWidget> {
  TextEditingController? _textController;
  bool _editing = false;
  final _focusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: "[New Subgoal]");
    } else {
      _textController!.text = "[New Subgoal]";
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.all(7.0),
            child: Icon(Icons.add, size: 18),
          ),
          _editing
              ? SizedBox(
                  width: 200,
                  child: TextField(
                    autocorrect: false,
                    controller: _textController,
                    decoration: null,
                    style: mainTextStyle,
                    onEditingComplete: () {
                      final newText = _textController!.text;
                      _textController!.text = "[New Subgoal]";
                      _textController!.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _textController!.text.length);
                      AppContext.of(context).syncClient.modifyGoal(
                          AppContext.of(context).syncClient.modifyGoal(
                              GoalDelta(
                                  id: const Uuid().v4(),
                                  text: newText,
                                  parentId: widget.parentId)));
                      setState(() {
                        _editing = false;
                      });
                    },
                    onTapOutside: (_) {
                      _textController!.text = "[New Subgoal]";
                      setState(() {
                        _editing = false;
                      });
                    },
                    focusNode: _focusNode,
                  ))
              : GestureDetector(
                  onTap: () => {
                    setState(() {
                      _editing = true;
                      _focusNode.requestFocus();
                      _textController!.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _textController!.text.length);
                    })
                  },
                  child: Text(_textController!.text, style: mainTextStyle),
                ),
        ],
      ),
    );
  }
}
