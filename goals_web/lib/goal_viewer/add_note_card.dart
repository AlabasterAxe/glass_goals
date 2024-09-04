import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:goals_core/sync.dart';
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import 'providers.dart'
    show EditingEvent, editingEventStream, isEditingTextProvider;

class AddNoteCard extends ConsumerStatefulWidget {
  final String goalId;
  const AddNoteCard({super.key, required this.goalId});

  @override
  ConsumerState<AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends ConsumerState<AddNoteCard> {
  bool _editing = false;
  late final _focusNode = FocusNode();
  StreamSubscription? _editingSubscription;

  final _defaultText = "[New Note]";
  late TextEditingController _textController =
      TextEditingController(text: this._defaultText);

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

  _potentiallyDiscardNote() {
    if (_textController.text == _defaultText) {
      _textController.text = _defaultText;
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
    ref.read(isEditingTextProvider.notifier).set(true);
    setState(() {
      if (_editingSubscription != null) {
        _editingSubscription!.cancel();
      }
      _editingSubscription = editingEventStream.listen((event) {
        switch (event) {
          case EditingEvent.accept:
            _createNote();
            break;
          case EditingEvent.discard:
            _potentiallyDiscardNote();
            break;
        }
      });
      _editing = true;
      _focusNode.requestFocus();
      _textController.selection = TextSelection(
          baseOffset: 0, extentOffset: _textController.text.length);
    });
  }

  _stopEditing() {
    _editingSubscription!.cancel();
    _editingSubscription = null;
    ref.read(isEditingTextProvider.notifier).set(false);
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, Function()>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
            _createNote,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
            _createNote,
        LogicalKeySet(LogicalKeyboardKey.escape): _discardNote,
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
                            onTapOutside: isNarrow
                                ? null
                                : (_) => _potentiallyDiscardNote(),
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
