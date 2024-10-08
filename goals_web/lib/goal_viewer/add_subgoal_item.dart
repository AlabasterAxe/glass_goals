import 'package:flutter/material.dart' show Colors, Icons, TextField;
import 'package:flutter/painting.dart' show EdgeInsets, EdgeInsetsGeometry;
import 'package:flutter/services.dart' show SystemMouseCursors, TextSelection;
import 'package:flutter/widgets.dart'
    show
        Actions,
        BuildContext,
        CallbackAction,
        Center,
        FocusNode,
        GestureDetector,
        Icon,
        IntrinsicWidth,
        MouseRegion,
        Padding,
        Row,
        SizedBox,
        Text,
        TextEditingController,
        Widget;
import 'package:goals_core/model.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/intents.dart' show AcceptIntent, CancelIntent;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;

import '../styles.dart';
import 'goal_actions_context.dart';

class AddSubgoalItemWidget extends ConsumerStatefulWidget {
  final GoalPath path;
  final EdgeInsetsGeometry padding;
  const AddSubgoalItemWidget({
    super.key,
    required this.path,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  ConsumerState<AddSubgoalItemWidget> createState() =>
      _AddSubgoalItemWidgetState();
}

class _AddSubgoalItemWidgetState extends ConsumerState<AddSubgoalItemWidget> {
  late TextEditingController _textController =
      TextEditingController(text: _defaultText);
  bool _editing = false;
  final FocusNode _focusNode = FocusNode();

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

  _cancelEditing() {
    this._textController.text = _defaultText;
    textFocusStream.add(null);
  }

  _addGoal() {
    final newText = _textController.text;
    _textController.text = _defaultText;
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);

    GoalActionsContext.of(context)
        .onAddGoal
        .call(widget.path.parentId, newText);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(textFocusProvider, (oldValue, newValue) {
      if (pathsMatch(this.widget.path, newValue.value)) {
        if (!pathsMatch(oldValue?.value, newValue.value) ||
            !_editing ||
            !_focusNode.hasFocus) {
          _focusNode.requestFocus();
          _textController.selection = TextSelection(
              baseOffset: 0, extentOffset: _textController.text.length);
          setState(() {
            _editing = true;
          });
        }
      } else {
        _focusNode.unfocus();
        setState(() {
          _editing = false;
        });
      }
    });
    return Actions(
      actions: {
        CancelIntent: CallbackAction<CancelIntent>(
          onInvoke: (_) {
            this._cancelEditing();
          },
        ),
        AcceptIntent: CallbackAction<AcceptIntent>(
          onInvoke: (_) {
            this._addGoal();
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: this.widget.padding,
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  textFocusStream.add(widget.path);
                },
                child: SizedBox(
                  width: uiUnit(10),
                  height: uiUnit(8),
                  child: const Center(child: Icon(Icons.add, size: 18)),
                ),
              ),
              _editing
                  ? IntrinsicWidth(
                      child: TextField(
                        autocorrect: false,
                        controller: _textController,
                        decoration: null,
                        style: mainTextStyle,
                        maxLines: null,
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
        ),
      ),
    );
  }
}
