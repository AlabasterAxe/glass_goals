import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/styles.dart';

import '../app_context.dart';

class AddNoteCard extends StatefulWidget {
  final String goalId;
  const AddNoteCard({super.key, required this.goalId});

  @override
  State<AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends State<AddNoteCard> {
  TextEditingController? _textController;
  bool _editing = false;
  final _focusNode = FocusNode();

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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        children: [
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
                          id: widget.goalId,
                          logEntry: NoteLogEntry(
                              creationTime: DateTime.now(), text: newText)));
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
