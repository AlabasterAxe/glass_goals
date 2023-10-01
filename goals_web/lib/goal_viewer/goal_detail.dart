import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show ArchiveNoteLogEntry, GoalDelta, GoalLogEntry, NoteLogEntry;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/styles.dart' show mainTextStyle;

class NoteCard extends StatefulWidget {
  final String goalId;
  final NoteLogEntry entry;
  final Function() onRefresh;
  const NoteCard(
      {super.key,
      required this.goalId,
      required this.entry,
      required this.onRefresh});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class SaveNoteIntent extends Intent {
  const SaveNoteIntent();
}

class _NoteCardState extends State<NoteCard> {
  late TextEditingController _textController;
  bool _editing = false;
  late final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _textController = TextEditingController(text: widget.entry.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  late final macBindings = <ShortcutActivator, Function()>{
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter): _saveNote,
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
        _saveNote,
  };

  _saveNote() {
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: widget.goalId,
        logEntry: NoteLogEntry(
            id: widget.entry.id,
            creationTime: DateTime.now(),
            text: _textController.text)));
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: macBindings,
      child: Row(
        children: [
          Expanded(
            child: _editing
                ? IntrinsicHeight(
                    child: TextField(
                      autocorrect: false,
                      controller: _textController,
                      decoration: null,
                      maxLines: null,
                      style: mainTextStyle,
                      onTapOutside: (_) {
                        _textController.text = widget.entry.text;
                        setState(() {
                          _editing = false;
                        });
                      },
                      focusNode: _focusNode,
                    ),
                  )
                : MarkdownBody(data: _textController.text, selectable: true),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      _editing = true;
                      _focusNode.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.edit)),
              IconButton(
                  onPressed: () {
                    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                        id: widget.goalId,
                        logEntry: ArchiveNoteLogEntry(
                            id: widget.entry.id,
                            creationTime: DateTime.now())));
                    widget.onRefresh();
                  },
                  icon: const Icon(Icons.delete)),
            ],
          ),
        ],
      ),
    );
  }
}

class GoalDetail extends StatefulWidget {
  final Goal goal;
  const GoalDetail({super.key, required this.goal});

  @override
  State<GoalDetail> createState() => _GoalDetailState();
}

class _GoalDetailState extends State<GoalDetail> {
  List<NoteLogEntry> _computeNoteLog(List<GoalLogEntry> log) {
    Map<String, NoteLogEntry> entries = {};
    log.sort((a, b) => a.creationTime.compareTo(b.creationTime));
    for (final entry in log) {
      if (entry is NoteLogEntry) {
        final originalNoteDate = entries[entry.id]?.creationTime;
        entries[entry.id] = NoteLogEntry(
            creationTime: originalNoteDate ?? entry.creationTime,
            text: entry.text,
            id: entry.id);
      } else if (entry is ArchiveNoteLogEntry) {
        entries.remove(entry.id);
      }
    }

    final entriesList = entries.values.toList();
    entriesList.sort((a, b) => b.creationTime.compareTo(a.creationTime));
    return entriesList;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AddNoteCard(goalId: widget.goal.id),
      for (final entry in _computeNoteLog(widget.goal.log))
        NoteCard(
            key: ValueKey(entry.id),
            goalId: widget.goal.id,
            entry: entry,
            onRefresh: () => setState(() {})),
    ]);
  }
}
