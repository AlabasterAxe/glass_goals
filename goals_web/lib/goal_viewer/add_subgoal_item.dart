import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../app_context.dart';
import '../styles.dart';

class AddSubgoalItemWidget extends StatefulWidget {
  final String? parentId;
  const AddSubgoalItemWidget({
    super.key,
    this.parentId,
  });

  @override
  State<AddSubgoalItemWidget> createState() => _AddSubgoalItemWidgetState();
}

class _AddSubgoalItemWidgetState extends State<AddSubgoalItemWidget> {
  TextEditingController? _textController;
  bool _editing = false;
  final _focusNode = FocusNode();

  String get _defaultText =>
      widget.parentId == null ? "[New Goal]" : "[New Subgoal]";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: _defaultText);
    } else {
      _textController!.text = _defaultText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        children: [
          SizedBox(
            width: uiUnit(10),
            height: uiUnit(10),
            child: const Center(child: Icon(Icons.add, size: 18)),
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
                      _textController!.text = _defaultText;
                      _textController!.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _textController!.text.length);
                      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                          id: const Uuid().v4(),
                          text: newText,
                          parentId: widget.parentId));
                      setState(() {
                        _editing = false;
                      });
                    },
                    onTapOutside: (_) {
                      _textController!.text = _defaultText;
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
                  child: Text(_textController!.text,
                      style: mainTextStyle.copyWith(color: Colors.black54)),
                ),
        ],
      ),
    );
  }
}
