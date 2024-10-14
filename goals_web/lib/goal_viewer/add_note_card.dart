import 'package:flutter/material.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/goal_viewer_constants.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/intents.dart';
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:uuid/uuid.dart';

import '../app_context.dart';

class AddNoteCard extends ConsumerStatefulWidget {
  final String goalId;
  const AddNoteCard({super.key, required this.goalId});

  GoalPath get path => GoalPath([goalId, NEW_NOTE_PLACEHOLDER]);

  @override
  ConsumerState<AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends ConsumerState<AddNoteCard> {
  bool _editing = false;
  final FocusNode _focusNode = FocusNode();

  final _defaultText = "[New Note]";
  late final TextEditingController _textController =
      TextEditingController(text: this._defaultText);

  @override
  void initState() {
    super.initState();

    if (pathsMatch(textFocusStream.value, this.widget.path)) {
      _startEditing();
    }

    this._focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _saveNoteIfNecessary();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  _createNote() {
    final newText = _textController.text;
    _textController.text = _defaultText;
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: widget.goalId,
        logEntry: NoteLogEntry(
            id: const Uuid().v4(),
            creationTime: DateTime.now(),
            text: newText)));
    _stopEditing();
  }

  _saveNoteIfNecessary() {
    if (_textController.text == _defaultText) {
      _stopEditing();
    } else {
      _createNote();
    }
  }

  _discardNote() {
    _textController.text = _defaultText;
    _stopEditing();
  }

  _startEditing() {
    textFocusStream.add(widget.path);
  }

  _stopEditing() {
    textFocusStream.add(null);
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
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
        AcceptMultiLineTextIntent: CallbackAction<AcceptMultiLineTextIntent>(
            onInvoke: (_) => _createNote()),
        CancelIntent: CallbackAction<CancelIntent>(
          onInvoke: (_) => _discardNote(),
        ),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: uiUnit(10),
                height: uiUnit(8),
                child: const Center(child: Icon(Icons.add, size: 18)),
              ),
              Flexible(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: _editing
                      ? IntrinsicHeight(
                          child: TextField(
                            autocorrect: false,
                            controller: _textController,
                            decoration: null,
                            maxLines: null,
                            style: mainTextStyle,
                            onTapOutside:
                                isNarrow ? null : (_) => _saveNoteIfNecessary(),
                            focusNode: _focusNode,
                          ),
                        )
                      : GestureDetector(
                          onTap: _startEditing,
                          child: Text(_textController.text,
                              style: mainTextStyle.copyWith(
                                  color: Colors.black54)),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
