import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart'
    show Goal, getGoalStatus, getGoalsMatchingPredicate;
import 'package:goals_core/sync.dart'
    show
        ArchiveNoteLogEntry,
        ArchiveStatusLogEntry,
        GoalDelta,
        GoalLogEntry,
        GoalStatus,
        NoteLogEntry,
        SetParentLogEntry,
        StatusLogEntry;
import 'package:goals_core/util.dart' show formatDate, formatTime;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/goal_viewer/goal_search_modal.dart'
    show GoalSearchModal;
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:goals_web/styles.dart'
    show darkElementColor, lightBackground, mainTextStyle, uiUnit;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget, ConsumerWidget, WidgetRef;
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl;
import 'package:uuid/uuid.dart';

import '../widgets/gg_icon_button.dart';
import 'flattened_goal_tree.dart' show FlattenedGoalTree;

class Breadcrumb extends ConsumerWidget {
  final Goal goal;
  const Breadcrumb({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          child: Text(goal.text),
          onTap: () {
            ref.read(focusedGoalProvider.notifier).set(goal.id);
          }),
    );
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

class StatusCard extends StatelessWidget {
  final Goal goal;
  final StatusLogEntry entry;
  final bool childEntry;
  final bool archived;
  final bool showDate;
  const StatusCard({
    super.key,
    required this.goal,
    required this.entry,
    required this.childEntry,
    this.archived = false,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: uiUnit(10),
          height: uiUnit(8),
          child: const Center(child: Icon(Icons.remove, size: 18)),
        ),
        if (this.childEntry)
          Row(
            children: [
              Breadcrumb(goal: this.goal),
              const Text(':'),
              SizedBox(width: uiUnit(2)),
            ],
          ),
        this.archived ? Text('Cleared') : Text('Set'),
        SizedBox(width: uiUnit(2)),
        StatusChip(
            entry: this.entry,
            goalId: this.goal.id,
            showArchiveButton: false,
            verbose: true),
        Text(" - "),
        if (showDate) Text('${formatDate(this.entry.creationTime)} '),
        Text(formatTime(this.entry.creationTime)),
      ],
    );
  }
}

class NoteCard extends StatefulWidget {
  final Goal goal;
  final NoteLogEntry entry;
  final Function() onRefresh;
  final bool childNote;
  final bool showDate;
  const NoteCard({
    super.key,
    required this.goal,
    required this.entry,
    required this.onRefresh,
    required this.childNote,
    this.showDate = false,
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

  _discardEdit() {
    _textController.text = widget.entry.text;
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: uiUnit(10),
                  height: uiUnit(8),
                  child: const Center(child: Icon(Icons.remove, size: 18)),
                ),
                if (widget.childNote) ...[
                  Breadcrumb(goal: widget.goal),
                  Text(" - ")
                ],
                if (this.widget.showDate)
                  Text('${formatDate(this.widget.entry.creationTime)} '),
                Text(formatTime(widget.entry.creationTime)),
              ],
            ),
            !widget.childNote
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GlassGoalsIconButton(
                          onPressed: () {
                            AppContext.of(context).syncClient.modifyGoal(
                                GoalDelta(
                                    id: widget.goal.id,
                                    logEntry: ArchiveNoteLogEntry(
                                        id: widget.entry.id,
                                        creationTime: DateTime.now())));
                            widget.onRefresh();
                          },
                          icon: Icons.delete),
                    ],
                  )
                : Container(),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: uiUnit(10), bottom: uiUnit(4)),
          child: _editing
              ? IntrinsicHeight(
                  child: FocusScope(
                    parentNode: FocusManager.instance.rootScope,
                    child: CallbackShortcuts(
                      bindings: <ShortcutActivator, Function()>{
                        LogicalKeySet(LogicalKeyboardKey.meta,
                            LogicalKeyboardKey.enter): _saveNote,
                        LogicalKeySet(LogicalKeyboardKey.control,
                            LogicalKeyboardKey.enter): _saveNote,
                        LogicalKeySet(LogicalKeyboardKey.escape): _discardEdit,
                      },
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
                    ),
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

class DetailViewLogEntryDateItem {
  final String dateString;
  final List<DetailViewLogEntryItem> logItems;
  const DetailViewLogEntryDateItem(
      {required this.dateString, required this.logItems});
}

class DetailViewLogEntryItem {
  final Goal goal;
  final GoalLogEntry entry;
  final bool archived;
  const DetailViewLogEntryItem(
      {required this.goal, required this.entry, this.archived = false});
}

class DetailViewLogEntryDateWidget extends StatelessWidget {
  final DetailViewLogEntryDateItem item;
  final String goalId;
  final VoidCallback onRefresh;
  const DetailViewLogEntryDateWidget(
      {super.key,
      required this.item,
      required this.goalId,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(uiUnit(2)),
              child: Container(
                height: uiUnit(.5),
                color: darkElementColor,
              ),
            ),
          ),
          ConstrainedBox(
              constraints: BoxConstraints(minHeight: uiUnit(8)),
              child: Center(
                  child: Text(
                this.item.dateString,
              ))),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(uiUnit(2)),
              child: Container(
                height: uiUnit(.5),
                color: darkElementColor,
              ),
            ),
          ),
        ],
      ),
      if (this.item.dateString == formatDate(DateTime.now()))
        AddNoteCard(goalId: this.goalId),
      for (final item in this.item.logItems)
        ConstrainedBox(
            constraints: BoxConstraints(minHeight: uiUnit(8)),
            child: switch (item.entry) {
              NoteLogEntry() => NoteCard(
                  key: ValueKey((item.entry as NoteLogEntry).id),
                  goal: item.goal,
                  entry: item.entry as NoteLogEntry,
                  childNote: item.goal.id != this.goalId,
                  onRefresh: this.onRefresh,
                ),
              StatusLogEntry() => StatusCard(
                  key: ValueKey(
                      "${item.entry.id}${item.archived ? '-archive' : ''}"),
                  goal: item.goal,
                  entry: item.entry as StatusLogEntry,
                  childEntry: item.goal.id != this.goalId,
                  archived: item.archived,
                ),
              _ => throw UnimplementedError()
            })
    ]);
  }
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

  List<DetailViewLogEntryDateItem> _computeHistoryLog(
      List<DetailViewLogEntryItem> log) {
    Map<String, DetailViewLogEntryItem> items = {};
    log.sort((a, b) => a.entry.creationTime.compareTo(b.entry.creationTime));
    for (final item in log) {
      final entry = item.entry;
      switch (entry) {
        case NoteLogEntry():
          final originalNoteDate = items[entry.id]?.entry.creationTime;
          items[entry.id] = DetailViewLogEntryItem(
              entry: NoteLogEntry(
                id: entry.id,
                creationTime: originalNoteDate ?? entry.creationTime,
                text: entry.text,
              ),
              goal: item.goal);
          break;
        case ArchiveNoteLogEntry():
          items.remove(entry.id);
          break;
        case ArchiveStatusLogEntry():
          final archivedStatusEntry = items[entry.id]?.entry;
          if (archivedStatusEntry != null &&
              archivedStatusEntry is StatusLogEntry) {
            // TODO: I'm not crazy about the way I'm doing this.
            items["${entry.id}-archive"] = DetailViewLogEntryItem(
                entry: StatusLogEntry(
                  id: entry.id,
                  creationTime: entry.creationTime,
                  status: archivedStatusEntry.status,
                  endTime: archivedStatusEntry.endTime,
                  startTime: archivedStatusEntry.startTime,
                ),
                archived: true,
                goal: item.goal);
          }
        case StatusLogEntry() || ArchiveStatusLogEntry():
          items[entry.id] = DetailViewLogEntryItem(
            entry: entry,
            goal: item.goal,
          );
          break;
        default:
        // ignore: no-empty-block
      }
    }

    final sortedItems = items.values.toList()
      ..sort((a, b) => b.entry.creationTime.compareTo(a.entry.creationTime));

    final List<DetailViewLogEntryDateItem> result = [];
    for (final item in sortedItems) {
      final dateString = formatDate(item.entry.creationTime);
      final lastItem = result.lastOrNull;
      if (lastItem != null && lastItem.dateString == dateString) {
        lastItem.logItems.add(item);
      } else {
        result.add(DetailViewLogEntryDateItem(
            dateString: dateString, logItems: [item]));
      }
    }
    return result;
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
    final historyLog = _computeHistoryLog(logItems);
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
                    CurrentStatusChip(goal: widget.goal)
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
        Text('History', style: textTheme.headlineSmall),
        SizedBox(height: uiUnit(1)),
        for (final item in historyLog)
          DetailViewLogEntryDateWidget(
              item: item,
              goalId: this.widget.goal.id,
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
