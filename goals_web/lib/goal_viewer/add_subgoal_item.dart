import 'package:flutter/material.dart';

import '../styles.dart';

class AddSubgoalItemWidget extends StatefulWidget {
  final String? parentId;
  final Function(String? parentId, String text) onAddGoal;
  const AddSubgoalItemWidget({
    super.key,
    this.parentId,
    required this.onAddGoal,
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

  _addGoal() {
    final newText = _textController!.text;
    _textController!.text = _defaultText;
    _textController!.selection = TextSelection(
        baseOffset: 0, extentOffset: _textController!.text.length);

    widget.onAddGoal(widget.parentId, newText);
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
              ? IntrinsicWidth(
                  child: TextField(
                    autocorrect: false,
                    controller: _textController,
                    decoration: null,
                    style: mainTextStyle,
                    onEditingComplete: _addGoal,
                    onTapOutside: (_) {
                      if (_textController!.text != _defaultText) {
                        _addGoal();
                      }
                      setState(() {
                        _editing = false;
                      });
                    },
                    focusNode: _focusNode,
                  ),
                )
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
