import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;

import '../styles.dart';
import 'goal_actions_context.dart';

class AddSubgoalItemWidget extends ConsumerStatefulWidget {
  final List<String> path;
  const AddSubgoalItemWidget({
    super.key,
    required this.path,
  });

  @override
  ConsumerState<AddSubgoalItemWidget> createState() =>
      _AddSubgoalItemWidgetState();
}

class _AddSubgoalItemWidgetState extends ConsumerState<AddSubgoalItemWidget> {
  late TextEditingController _textController =
      TextEditingController(text: _defaultText);
  bool _editing = false;
  late final FocusNode _focusNode = FocusNode(onKeyEvent: (node, event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      this._textController.text = _defaultText;
      textFocusStream.add(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  String get _defaultText =>
      widget.path.length < 3 ? "[New Goal]" : "[New Subgoal]";

  @override
  void initState() {
    super.initState();

    if (pathsMatch(textFocusStream.value, this.widget.path)) {
      setState(() {
        _editing = true;
        _focusNode.requestFocus();
        _textController.selection = TextSelection(
            baseOffset: 0, extentOffset: _textController.text.length);
      });
    }
  }

  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  _addGoal() {
    final newText = _textController.text;
    _textController.text = _defaultText;
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);

    GoalActionsContext.of(context).onAddGoal.call(
        widget.path.length >= 3 ? widget.path[widget.path.length - 2] : null,
        newText);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(textFocusProvider, (oldValue, newValue) {
      if (pathsMatch(this.widget.path, newValue.value)) {
        if (!pathsMatch(oldValue?.value, newValue.value)) {
          setState(() {
            _editing = true;
            _focusNode.requestFocus();
            _textController.selection = TextSelection(
                baseOffset: 0, extentOffset: _textController.text.length);
          });
        }
      } else {
        setState(() {
          _editing = false;
          _focusNode.unfocus();
        });
      }
    });
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        children: [
          SizedBox(
            width: uiUnit(10),
            height: uiUnit(8),
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
                      if (_textController.text != _defaultText &&
                          _textController.text.isNotEmpty) {
                        _addGoal();
                      }
                      textFocusStream.add(null);
                    },
                    focusNode: _focusNode,
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    textFocusStream.add(widget.path);
                  },
                  child: Text(_textController.text,
                      style: mainTextStyle.copyWith(color: Colors.black54)),
                ),
        ],
      ),
    );
  }
}
