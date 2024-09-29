import 'package:flutter/material.dart' show Colors, Icons, TextField;
import 'package:flutter/painting.dart'
    show EdgeInsets, TextBaseline, TextScaler, TextStyle;
import 'package:flutter/widgets.dart'
    show
        Actions,
        BoxConstraints,
        BuildContext,
        CallbackAction,
        Column,
        ConstrainedBox,
        Container,
        CrossAxisAlignment,
        Expanded,
        FocusNode,
        IntrinsicHeight,
        MainAxisAlignment,
        Padding,
        Row,
        SizedBox,
        State,
        StatefulWidget,
        Text,
        TextEditingController,
        TextSelection,
        Widget;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart'
    show ArchiveNoteLogEntry, GoalDelta, NoteLogEntry, SetSummaryEntry;
import 'package:goals_core/util.dart' show formatDate, formatTime;
import 'package:goals_web/app_context.dart' show AppContext;
import 'package:goals_web/common/constants.dart';
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/intents.dart';
import 'package:goals_web/styles.dart';
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class NoteCard extends StatefulWidget {
  final Goal goal;
  final NoteLogEntry? noteEntry;
  final SetSummaryEntry? summaryEntry;
  final Function() onRefresh;
  final bool isChildGoal;
  final bool showDate;
  final bool showTime;
  const NoteCard({
    super.key,
    required this.goal,
    this.noteEntry,
    this.summaryEntry,
    required this.onRefresh,
    required this.isChildGoal,
    this.showDate = false,
    this.showTime = true,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late TextEditingController _textController = TextEditingController(
      text: widget.noteEntry?.text ?? widget.summaryEntry?.text);
  bool _editing = false;
  late final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  _saveNote() {
    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);

    if (widget.noteEntry != null) {
      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
          id: widget.goal.id,
          logEntry: NoteLogEntry(
              id: widget.noteEntry!.id,
              creationTime: DateTime.now(),
              text: _textController.text)));
    } else {
      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
          id: widget.goal.id,
          logEntry: SetSummaryEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              text: _textController.text)));
    }
    setState(() {
      _editing = false;
    });
  }

  @override
  didUpdateWidget(NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.noteEntry?.text ?? widget.summaryEntry?.text;
    if (text != null && widget.goal.id != oldWidget.goal.id) {
      _textController.text = text;
    }
  }

  _discardEdit() {
    final text = widget.noteEntry?.text ?? widget.summaryEntry?.text;
    if (text != null) {
      _textController.text = text;
    }
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (this.widget.noteEntry != null)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: uiUnit(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (this.widget.showDate)
                        Text(
                            '${formatDate(this.widget.noteEntry?.creationTime ?? this.widget.summaryEntry!.creationTime)} '),
                      if (this.widget.showTime)
                        Text(formatTime(widget.noteEntry?.creationTime ??
                            widget.summaryEntry!.creationTime)),
                      if (widget.isChildGoal) ...[
                        Text(" - "),
                        Breadcrumb(goal: widget.goal),
                        SizedBox(width: uiUnit(2)),
                        Expanded(
                            child: Container(
                                height: uiUnit(.5), color: darkElementColor)),
                      ],
                    ],
                  ),
                ),
                !widget.isChildGoal
                    ? GlassGoalsIconButton(
                        onPressed: () {
                          AppContext.of(context).syncClient.modifyGoal(
                              GoalDelta(
                                  id: widget.goal.id,
                                  logEntry: ArchiveNoteLogEntry(
                                      id: widget.noteEntry!.id,
                                      creationTime: DateTime.now())));
                          widget.onRefresh();
                        },
                        icon: Icons.delete)
                    : Container(),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: uiUnit(4)),
          child: _editing
              ? IntrinsicHeight(
                  child: Actions(
                    actions: {
                      AcceptMultiLineTextIntent:
                          CallbackAction(onInvoke: (_) => _saveNote()),
                      CancelIntent:
                          CallbackAction(onInvoke: (_) => _discardEdit()),
                    },
                    child: TextField(
                      autocorrect: false,
                      controller: _textController,
                      decoration: null,
                      maxLines: null,
                      style: mainTextStyle,
                      onTapOutside: (_) {
                        if (widget.noteEntry?.text != null &&
                                _textController.text !=
                                    widget.noteEntry!.text ||
                            widget.summaryEntry?.text != null &&
                                _textController.text !=
                                    widget.summaryEntry?.text) {
                          _saveNote();
                        }
                        setState(() {
                          _editing = false;
                        });
                      },
                      focusNode: _focusNode,
                    ),
                  ),
                )
              : MarkdownBody(
                  data: _textController.text,
                  selectable: true,
                  listItemCrossAxisAlignment:
                      MarkdownListItemCrossAxisAlignment.baseline,
                  bulletBuilder: (params) {
                    switch (params.style) {
                      case BulletStyle.orderedList:
                        return Text("${params.index + 1}.",
                            style: TextStyle(
                                fontSize: 20,
                                textBaseline: TextBaseline.alphabetic));
                      case BulletStyle.unorderedList:
                        return Text("⬤", style: TextStyle(fontSize: 8));
                    }
                  },
                  onTapText: () {
                    if (!widget.isChildGoal) {
                      setState(() {
                        if (_textController.text == DEFAULT_SUMMARY_TEXT) {
                          _textController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _textController.text.length);
                        }

                        _editing = true;
                        _focusNode.requestFocus();
                      });
                    }
                  },
                  onTapLink: (text, href, title) async {
                    if (href == null) {
                      return;
                    }

                    final url = Uri.parse(href);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    textScaler: TextScaler.linear(1.05),
                    p: _textController.text == DEFAULT_SUMMARY_TEXT
                        ? mainTextStyle.copyWith(color: Colors.black54)
                        : mainTextStyle,
                  )),
        ),
      ],
    );
  }
}
