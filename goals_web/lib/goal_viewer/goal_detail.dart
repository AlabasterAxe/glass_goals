import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart'
    show Goal, getGoalStatus, getGoalsMatchingPredicate;
import 'package:goals_core/sync.dart'
    show
        ArchiveNoteLogEntry,
        GoalDelta,
        GoalLogEntry,
        GoalStatus,
        NoteLogEntry,
        SetParentLogEntry;
import 'package:goals_core/util.dart' show formatDate;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/goal_viewer/goal_search_modal.dart'
    show GoalSearchModal;
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:goals_web/styles.dart'
    show lightBackground, mainTextStyle, uiUnit;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget, ConsumerWidget, WidgetRef;
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl;
import 'package:uuid/uuid.dart';

import 'flattened_goal_tree.dart' show FlattenedGoalTree;

class Breadcrumb extends ConsumerWidget {
  final Goal goal;
  const Breadcrumb({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
        child: Text(goal.text),
        onTap: () {
          ref.read(focusedGoalProvider.notifier).set(goal.id);
        });
  }
}

class AddParentBreadcrumb extends StatefulWidget {
  final String goalId;
  const AddParentBreadcrumb({
    super.key,
    required this.goalId,
  });

  @override
  State<AddParentBreadcrumb> createState() => _AddParentBreadcrumbState();
}

class _AddParentBreadcrumbState extends State<AddParentBreadcrumb> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          GestureDetector(
              child: Text("+ Add Parent"),
              onTap: () async {
                final newParentId = await showDialog(
                    barrierColor: Colors.black26,
                    context: context,
                    builder: (context) => Dialog(
                          surfaceTintColor: Colors.transparent,
                          backgroundColor: lightBackground,
                          alignment: FractionalOffset.topCenter,
                          child: StreamBuilder<Map<String, Goal>>(
                              stream: AppContext.of(context)
                                  .syncClient
                                  .stateSubject,
                              builder: (context, snapshot) => GoalSearchModal(
                                    goalMap: snapshot.data ?? Map(),
                                  )),
                        ));
                if (newParentId != null) {
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: widget.goalId,
                      logEntry: SetParentLogEntry(
                          id: Uuid().v4(),
                          creationTime: DateTime.now(),
                          parentId: newParentId)));
                }
              }),
        ],
      ),
    );
  }
}

class NoteCard extends StatefulWidget {
  final Goal goal;
  final NoteLogEntry entry;
  final Function() onRefresh;
  final bool childNote;
  const NoteCard({
    super.key,
    required this.goal,
    required this.entry,
    required this.onRefresh,
    required this.childNote,
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
        id: widget.goal.id,
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
                  ...(widget.childNote
                      ? [const Text(' - '), Breadcrumb(goal: widget.goal)]
                      : [Container()])
                ],
              ),
              !widget.childNote
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                            onPressed: () {
                              AppContext.of(context).syncClient.modifyGoal(
                                  GoalDelta(
                                      id: widget.goal.id,
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
                      if (!widget.childNote) {
                        setState(() {
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
                      textScaleFactor: 1.4,
                    )),
          ),
        ],
      ),
    );
  }
}

class GoalDetail extends ConsumerStatefulWidget {
  final Goal goal;
  final Map<String, Goal> goalMap;
  final Function(String goalId) onSelected;
  final Function(String goalId, {bool? expanded}) onExpanded;
  final Function(String goalId) onFocused;
  final Function(String? parentId, String text) onAddGoal;
  final Function(
    String goalId, {
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) onDropGoal;
  final HoverActionsBuilder hoverActionsBuilder;
  const GoalDetail({
    super.key,
    required this.goal,
    required this.goalMap,
    required this.onSelected,
    required this.onExpanded,
    required this.onFocused,
    required this.hoverActionsBuilder,
    required this.onAddGoal,
    required this.onDropGoal,
  });

  @override
  ConsumerState<GoalDetail> createState() => _GoalDetailState();
}

class DetailViewLogEntryItem {
  final Goal goal;
  final GoalLogEntry entry;
  const DetailViewLogEntryItem({required this.goal, required this.entry});
}

class _GoalDetailState extends ConsumerState<GoalDetail> {
  var _editing = false;
  late final _textController = TextEditingController(text: widget.goal.text);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.goal.text != oldWidget.goal.text) {
      _textController.text = widget.goal.text;
    }
  }

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
            goal: item.goal);
      } else if (entry is ArchiveNoteLogEntry) {
        items.remove(entry.id);
      }
    }

    return items.values.toList()
      ..sort((a, b) => b.entry.creationTime.compareTo(a.entry.creationTime));
  }

  Widget breadcrumbs() {
    final List<Widget> widgets = [];
    Goal? curGoal = widget.goal.superGoals.firstOrNull;
    if (curGoal == null) {
      widgets.add(AddParentBreadcrumb(goalId: widget.goal.id));
    } else {
      while (curGoal != null) {
        widgets.add(Breadcrumb(goal: curGoal));
        widgets.add(const Icon(Icons.chevron_right));
        curGoal = curGoal.superGoals.firstOrNull;
      }
      widgets.removeLast();
    }

    return Row(children: widgets.reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    final isDebugMode = ref.watch(debugProvider);
    final worldContext = ref.watch(worldContextProvider);
    final List<DetailViewLogEntryItem> logItems = [];
    for (final goal in [...widget.goal.subGoals, widget.goal]) {
      logItems.addAll(goal.log
          .map((entry) => DetailViewLogEntryItem(goal: goal, entry: entry)));
    }
    final textTheme = Theme.of(context).textTheme;
    final noteLog = _computeNoteLog(logItems);
    final subgoalMap =
        getGoalsMatchingPredicate(worldContext, widget.goalMap, (goal) {
      final status = getGoalStatus(worldContext, goal);
      return status.status != GoalStatus.archived &&
          status.status != GoalStatus.done;
    });
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: EdgeInsets.all(uiUnit(2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!isNarrow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _editing
                        ? IntrinsicWidth(
                            child: TextField(
                              autocorrect: false,
                              controller: _textController,
                              decoration: null,
                              style: textTheme.headlineMedium,
                              onEditingComplete: () {
                                AppContext.of(context).syncClient.modifyGoal(
                                    GoalDelta(
                                        id: widget.goal.id,
                                        text: _textController.text));
                                setState(() {
                                  _editing = false;
                                });
                              },
                              onTapOutside: (_) {
                                setState(() {
                                  _editing = false;
                                });
                              },
                              focusNode: _focusNode,
                            ),
                          )
                        : Flexible(
                            child: GestureDetector(
                              onDoubleTap: _editing
                                  ? null
                                  : () => {
                                        setState(() {
                                          _editing = true;
                                          _focusNode.requestFocus();
                                        })
                                      },
                              child: Text(
                                widget.goal.text,
                                style: textTheme.headlineMedium,
                              ),
                            ),
                          ),
                    SizedBox(width: uiUnit(2)),
                    StatusChip(goal: widget.goal)
                  ]),
              widget.hoverActionsBuilder(widget.goal.id),
            ],
          ),
        breadcrumbs(),
        SizedBox(height: uiUnit(2)),
        Text('Subgoals', style: textTheme.headlineSmall),
        SizedBox(height: uiUnit(1)),
        FlattenedGoalTree(
          goalMap: subgoalMap,
          rootGoalIds: widget.goal.subGoals
              .where((g) => subgoalMap.containsKey(g.id))
              .map((g) => g.id)
              .toList(),
          hoverActionsBuilder: widget.hoverActionsBuilder,
          path: [widget.goal.id],
          section: 'detail',
        ),
        SizedBox(height: uiUnit(2)),
        Text('Notes', style: textTheme.headlineSmall),
        SizedBox(height: uiUnit(1)),
        noteLog.firstOrNull == null ||
                formatDate(noteLog.first.entry.creationTime) !=
                    formatDate(DateTime.now()) ||
                noteLog.first.goal.id != widget.goal.id
            ? AddNoteCard(goalId: widget.goal.id)
            : Container(),
        for (final entry in noteLog)
          NoteCard(
              key: ValueKey((entry.entry as NoteLogEntry).id),
              goal: entry.goal,
              entry: entry.entry as NoteLogEntry,
              childNote: entry.goal.id != widget.goal.id,
              onRefresh: () => setState(() {})),
        if (isDebugMode) ...[
          SizedBox(height: uiUnit(2)),
          Text('Debug Info', style: textTheme.headlineSmall),
          SizedBox(height: uiUnit(2)),
          Text('Goal ID: ${widget.goal.id}'),
          SizedBox(height: uiUnit(2)),
          for (final entry in widget.goal.log) Text(entry.toString())
        ],
      ]),
    );
  }
}
