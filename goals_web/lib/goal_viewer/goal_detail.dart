import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show ArchiveNoteLogEntry, GoalDelta, GoalLogEntry, NoteLogEntry;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/styles.dart' show mainTextStyle, uiUnit;
import 'package:goals_web/util/format_date.dart';

class NoteCard extends StatefulWidget {
  final String goalId;
  final NoteLogEntry entry;
  final Function() onRefresh;
  final bool editable;
  final String? goalText;
  const NoteCard({
    super.key,
    required this.goalId,
    required this.entry,
    required this.onRefresh,
    required this.editable,
    this.goalText,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
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
      bindings: <ShortcutActivator, Function()>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
            _saveNote,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
            _saveNote,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(formatDate(widget.entry.creationTime)),
                  widget.goalText != null
                      ? Text(' - ${widget.goalText!}')
                      : Container()
                ],
              ),
              widget.editable
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                            onPressed: () {
                              AppContext.of(context).syncClient.modifyGoal(
                                  GoalDelta(
                                      id: widget.goalId,
                                      logEntry: ArchiveNoteLogEntry(
                                          id: widget.entry.id,
                                          creationTime: DateTime.now())));
                              widget.onRefresh();
                            },
                            icon: const Icon(Icons.delete)),
                      ],
                    )
                  : Container(),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: uiUnit(4), bottom: uiUnit(4)),
            child: _editing
                ? IntrinsicHeight(
                    child: TextField(
                      autocorrect: false,
                      controller: _textController,
                      decoration: null,
                      maxLines: null,
                      style: mainTextStyle,
                      onTapOutside: (_) {
                        if (_textController.text != widget.entry.text) {
                          _saveNote();
                        }
                        setState(() {
                          _editing = false;
                        });
                      },
                      focusNode: _focusNode,
                    ),
                  )
                : MarkdownBody(
                    data: _textController.text,
                    selectable: true,
                    onTapText: () {
                      setState(() {
                        _editing = true;
                        _focusNode.requestFocus();
                      });
                    },
                    styleSheet: MarkdownStyleSheet(
                      textScaleFactor: 1.4,
                    )),
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

class DetailViewLogEntryItem {
  final String goalId;
  final String goalText;
  final GoalLogEntry entry;
  const DetailViewLogEntryItem(
      {required this.goalId, required this.goalText, required this.entry});
}

class _GoalDetailState extends State<GoalDetail> {
  List<DetailViewLogEntryItem> _computeNoteLog(
      List<DetailViewLogEntryItem> log) {
    Map<String, DetailViewLogEntryItem> items = {};
    log.sort((a, b) => a.entry.creationTime.compareTo(b.entry.creationTime));
    for (final item in log) {
      final entry = item.entry;
      if (entry is NoteLogEntry) {
        final originalNoteDate = items[entry.id]?.entry.creationTime;
        items[entry.id] = DetailViewLogEntryItem(
            entry: NoteLogEntry(
              id: entry.id,
              creationTime: originalNoteDate ?? entry.creationTime,
              text: entry.text,
            ),
            goalId: item.goalId,
            goalText: item.goalText);
      } else if (entry is ArchiveNoteLogEntry) {
        items.remove(entry.id);
      }
    }

    return items.values.toList()
      ..sort((a, b) => b.entry.creationTime.compareTo(a.entry.creationTime));
  }

  @override
  Widget build(BuildContext context) {
    final List<DetailViewLogEntryItem> logItems = [];
    for (final goal in [...widget.goal.subGoals, widget.goal]) {
      logItems.addAll(goal.log.map((entry) => DetailViewLogEntryItem(
          goalId: goal.id, goalText: goal.text, entry: entry)));
    }
    final textTheme = Theme.of(context).textTheme;
    final noteLog = _computeNoteLog(logItems);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.goal.text, style: textTheme.headlineMedium),
      SizedBox(height: uiUnit(2)),
      noteLog.firstOrNull == null ||
              formatDate(noteLog.first.entry.creationTime) !=
                  formatDate(DateTime.now())
          ? AddNoteCard(goalId: widget.goal.id)
          : Container(),
      for (final entry in noteLog)
        NoteCard(
            key: ValueKey((entry.entry as NoteLogEntry).id),
            goalId: widget.goal.id,
            entry: entry.entry as NoteLogEntry,
            editable: entry.goalId == widget.goal.id,
            goalText: entry.goalId != widget.goal.id ? entry.goalText : null,
            onRefresh: () => setState(() {})),
    ]);
  }
}
