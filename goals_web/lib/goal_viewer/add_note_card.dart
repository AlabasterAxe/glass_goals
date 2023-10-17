import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:goals_core/sync.dart';
import 'package:goals_web/styles.dart';
import 'package:goals_web/util/format_date.dart';
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
  TextEditingController? _textController;
  bool _editing = false;
  late final _focusNode = FocusNode();
  StreamSubscription? _editingSubscription;

  final _defaultText = "[New Note]";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: _defaultText);
    } else {
      _textController!.text = _defaultText;
    }
  }

  _createNote() {
    final newText = _textController!.text;
    _textController!.text = _defaultText;
    _textController!.selection = TextSelection(
        baseOffset: 0, extentOffset: _textController!.text.length);
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: widget.goalId,
        logEntry: NoteLogEntry(
            id: const Uuid().v4(),
            creationTime: DateTime.now(),
            text: newText)));
    _stopEditing();
  }

  _potentiallyDiscardNote() {
    if (_textController!.text == _defaultText) {
      _textController!.text = _defaultText;
      _stopEditing();
    } else {
      _createNote();
    }
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
      _textController!.selection = TextSelection(
          baseOffset: 0, extentOffset: _textController!.text.length);
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
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: uiUnit(10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(formatDate(DateTime.now())),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.only(left: uiUnit(4), bottom: uiUnit(4)),
              child: _editing
                  ? IntrinsicHeight(
                      child: TextField(
                        autocorrect: false,
                        controller: _textController,
                        decoration: null,
                        maxLines: null,
                        style: mainTextStyle,
                        onTapOutside:
                            isNarrow ? null : (_) => _potentiallyDiscardNote(),
                        focusNode: _focusNode,
                      ),
                    )
                  : GestureDetector(
                      onTap: _startEditing,
                      child: Text(_textController!.text,
                          style: mainTextStyle.copyWith(color: Colors.black54)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
