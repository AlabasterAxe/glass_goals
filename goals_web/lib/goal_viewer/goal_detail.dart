import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalLogEntry, NoteLogEntry;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/styles.dart' show mainTextStyle;

class NoteCard extends StatefulWidget {
  final String goalId;
  final NoteLogEntry entry;
  const NoteCard({super.key, required this.goalId, required this.entry});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  TextEditingController? _textController;
  bool _editing = false;
  final _focusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: widget.entry.text);
    } else {
      _textController!.text = widget.entry.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
                      _textController!.text = widget.entry.text;
                      _textController!.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _textController!.text.length);
                      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                          id: widget.goalId,
                          logEntry: NoteLogEntry(
                              id: widget.entry.id,
                              creationTime: DateTime.now(),
                              text: newText)));
                      setState(() {
                        _editing = false;
                      });
                    },
                    onTapOutside: (_) {
                      _textController!.text = widget.entry.text;
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
                  child: MarkdownBody(data: _textController!.text),
                ),
        ],
      ),
    );
  }
}

class GoalDetail extends StatelessWidget {
  final Goal goal;
  const GoalDetail({super.key, required this.goal});

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
      } else if (entry is NoteLogEntry) {
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
      AddNoteCard(goalId: goal.id),
      for (final entry in _computeNoteLog(goal.log))
        Card(child: MarkdownBody(data: entry.text))
    ]);
  }
}
