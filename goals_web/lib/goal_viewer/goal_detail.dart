import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart'
    show Goal, WorldContext, getGoalStatus, getGoalsMatchingPredicate;
import 'package:goals_core/sync.dart'
    show
        AddStatusIntentionLogEntry,
        AddStatusReflectionLogEntry,
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
import 'package:goals_web/goal_viewer/goal_actions_context.dart';
import 'package:goals_web/goal_viewer/goal_search_modal.dart'
    show GoalSearchModal;
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/printed_goal.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:goals_web/styles.dart'
    show darkElementColor, lightBackground, mainTextStyle, uiUnit;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget, ConsumerWidget, WidgetRef;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl;
import 'package:uuid/uuid.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../widgets/gg_icon_button.dart';
import 'flattened_goal_tree.dart' show FlattenedGoalTree;

List<DetailViewLogEntryYear> _computeHistoryLog(
    WorldContext worldContext, List<DetailViewLogEntryItem> log) {
  final List<DetailViewLogEntryYear> result = [];
  for (final item in _computeFlatHistoryLog(worldContext, log)) {
    final year = item.time.year;
    final month = item.time.month;
    final day = item.time.day;
    var currentYear = result.lastOrNull;
    if (currentYear == null || currentYear.year != year) {
      result.add(DetailViewLogEntryYear(year: year, logItems: []));
      currentYear = result.last;
    }

    var currentMonth = currentYear.logItems.lastOrNull;
    var currentDay = currentMonth?.logItems.lastOrNull;
    if (currentMonth == null || currentDay?.dayOfMonth != day) {
      currentYear.logItems
          .add(DetailViewLogEntryMonth(monthOfYear: month, logItems: []));
      currentMonth = currentYear.logItems.last;
    }

    currentDay = currentMonth.logItems.lastOrNull;
    if (currentDay == null || currentDay.dayOfMonth != day) {
      currentMonth.logItems
          .add(DetailViewLogEntryDay(dayOfMonth: day, logItems: [item]));
    } else {
      currentDay.logItems.add(item);
    }
  }

  return result;
}

List<DetailViewLogEntryItem> _computeFlatHistoryLog(
    WorldContext worldContext, List<DetailViewLogEntryItem> log) {
  Map<String, DetailViewLogEntryItem> items = {};
  log.sort((a, b) => a.entry.creationTime.compareTo(b.entry.creationTime));
  for (final item in log) {
    final entry = item.entry;
    switch (entry) {
      case NoteLogEntry():
        final originalNoteDate = items[entry.id]?.entry.creationTime;
        items[entry.id] = DetailViewLogEntryItem(
            entry: entry,
            time: originalNoteDate ?? entry.creationTime,
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
            entry: archivedStatusEntry,
            time: entry.creationTime,
            archived: true,
            goal: item.goal,
          );
        }
      case StatusLogEntry():
        items["${entry.id}-creation"] = DetailViewLogEntryItem(
          entry: entry,
          goal: item.goal,
          time: entry.creationTime,
        );

        // Only add an end entry for active statuses.
        if (entry.endTime != null &&
            entry.endTime != entry.creationTime &&
            entry.endTime!.isBefore(worldContext.time) &&
            entry.status == GoalStatus.active &&
            // If the goal is archived or done by the time the status ends, don't show the end entry.
            ![GoalStatus.archived, GoalStatus.done].contains(
                getGoalStatus(WorldContext(time: entry.endTime!), item.goal)
                    .status)) {
          items["${entry.id}-end"] = DetailViewLogEntryItem(
            entry: entry,
            goal: item.goal,
            time: entry.endTime!,
          );
        }

        break;
      case AddStatusIntentionLogEntry():
        final existingItem = items["${entry.statusId}-creation"];
        if (existingItem != null && existingItem.entry is StatusLogEntry) {
          items["${entry.statusId}-creation"] = DetailViewLogEntryItem(
            entry: existingItem.entry,
            goal: existingItem.goal,
            time: existingItem.time,
            statusNote: entry,
          );
        }
        break;

      case AddStatusReflectionLogEntry():
        // TODO: for done statuses, reflections are shown on the status creation
        //   for active statuses, reflections are shown on the status end
        var existingItem = items["${entry.statusId}-end"];
        var itemKey = "${entry.statusId}-end";

        if (existingItem?.entry is StatusLogEntry &&
            (existingItem!.entry as StatusLogEntry).status !=
                GoalStatus.active) {
          break;
        }

        if (existingItem == null) {
          existingItem = items["${entry.statusId}-creation"];
          itemKey = "${entry.statusId}-creation";
          if (existingItem?.entry is StatusLogEntry &&
              (existingItem!.entry as StatusLogEntry).status !=
                  GoalStatus.done) {
            break;
          }
        }
        if (existingItem != null && existingItem.entry is StatusLogEntry) {
          items[itemKey] = DetailViewLogEntryItem(
            entry: existingItem.entry,
            goal: existingItem.goal,
            time: existingItem.time,
            statusNote: entry,
          );
        }
        break;

      default:
      // ignore: no-empty-block
    }
  }

  final sortedItems = items.values.toList()
    ..sort((a, b) => b.time.compareTo(a.time));

  return sortedItems;
}

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
          child: Text(goal.text,
              style: TextStyle(decoration: TextDecoration.underline)),
          onTap: () {
            focusedGoalStream.add(goal.id);
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

class StatusCard extends ConsumerStatefulWidget {
  final Goal goal;
  final StatusLogEntry entry;
  final bool archived;
  final bool isStatusEnd;
  final DateTime time;
  final String? text;
  final bool isChildGoal;
  const StatusCard({
    super.key,
    required this.goal,
    required this.entry,
    this.archived = false,
    this.isStatusEnd = false,
    required this.time,
    this.text,
    required this.isChildGoal,
  });

  @override
  ConsumerState<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<StatusCard> {
  late TextEditingController _textController =
      TextEditingController(text: widget.text);
  bool _editing = false;
  late final _focusNode = FocusNode();

  _saveNote(String? noteType) {
    if (noteType == null) {
      return;
    }

    _textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);
    AppContext.of(context).syncClient.modifyGoal(GoalDelta(
        id: widget.goal.id,
        logEntry: noteType == "reflection"
            ? AddStatusReflectionLogEntry(
                id: Uuid().v4(),
                statusId: this.widget.entry.id,
                creationTime: DateTime.now(),
                reflectionText: _textController.text)
            : AddStatusIntentionLogEntry(
                id: Uuid().v4(),
                statusId: this.widget.entry.id,
                creationTime: DateTime.now(),
                intentionText: _textController.text)));
    setState(() {
      _editing = false;
    });
  }

  _discardEdit() {
    if (this.widget.text != null) {
      this._textController.text = this.widget.text!;
    }
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final noteType =
        this.widget.isStatusEnd || this.widget.entry.status == GoalStatus.done
            ? "reflection"
            : [GoalStatus.pending, GoalStatus.active]
                        .contains(this.widget.entry.status) &&
                    this.widget.entry.id ==
                        getGoalStatus(worldContext, widget.goal).id
                ? "intention"
                : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatTime(this.widget.time)),
            Text(" - "),
            if (this.widget.isChildGoal)
              Row(
                children: [
                  Breadcrumb(goal: this.widget.goal),
                  const Text(':'),
                  SizedBox(width: uiUnit(2)),
                ],
              ),
            if (this.widget.archived) ...[
              Text('Cleared'),
              SizedBox(width: uiUnit(2)),
            ],
            StatusChip(
              entry: this.widget.entry,
              goalId: this.widget.goal.id,
              showArchiveButton: false,
              until: !this.widget.isStatusEnd,
              since: this.widget.isStatusEnd,
            ),
            if (this.widget.isStatusEnd) ...[
              SizedBox(width: uiUnit(2)),
              Text('has ended.'),
            ],
            if (this.widget.text == null && noteType != null) ...[
              SizedBox(width: uiUnit(2)),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                    child: Text(
                        noteType == "reflection"
                            ? "How did it go?"
                            : "What are your plans?",
                        style: TextStyle(decoration: TextDecoration.underline)),
                    onTap: () {
                      setState(() {
                        _editing = true;
                        _focusNode.requestFocus();
                      });
                    }),
              )
            ]
          ],
        ),
        if (_editing || this.widget.text != null)
          Padding(
            padding: EdgeInsets.only(bottom: uiUnit(4)),
            child: _editing
                ? IntrinsicHeight(
                    child: FocusScope(
                      parentNode: FocusManager.instance.rootScope,
                      child: CallbackShortcuts(
                        bindings: <ShortcutActivator, Function()>{
                          LogicalKeySet(LogicalKeyboardKey.meta,
                                  LogicalKeyboardKey.enter):
                              () => _saveNote(noteType),
                          LogicalKeySet(LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.enter):
                              () => _saveNote(noteType),
                          LogicalKeySet(LogicalKeyboardKey.escape):
                              _discardEdit,
                        },
                        child: TextField(
                          autocorrect: false,
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: noteType == "reflection"
                                ? "Add any thoughts about how it went here."
                                : "Add your specific intentions for this time window.",
                          ),
                          maxLines: null,
                          style: mainTextStyle,
                          onTapOutside: (_) {
                            if (_textController.text != widget.text) {
                              _saveNote(noteType);
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
                    listItemCrossAxisAlignment:
                        MarkdownListItemCrossAxisAlignment.start,
                    data: _textController.text,
                    selectable: true,
                    onTapText: () {
                      setState(() {
                        _editing = true;
                        _focusNode.requestFocus();
                      });
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

class NoteCard extends StatefulWidget {
  final Goal goal;
  final NoteLogEntry entry;
  final Function() onRefresh;
  final bool isChildGoal;
  final bool showDate;
  const NoteCard({
    super.key,
    required this.goal,
    required this.entry,
    required this.onRefresh,
    required this.isChildGoal,
    this.showDate = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late TextEditingController _textController =
      TextEditingController(text: widget.entry.text);
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
                      Text('${formatDate(this.widget.entry.creationTime)} '),
                    Text(formatTime(widget.entry.creationTime)),
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
                        AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                            id: widget.goal.id,
                            logEntry: ArchiveNoteLogEntry(
                                id: widget.entry.id,
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
                  listItemCrossAxisAlignment:
                      MarkdownListItemCrossAxisAlignment.start,
                  data: _textController.text,
                  selectable: true,
                  onTapText: () {
                    if (!widget.isChildGoal) {
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

class DetailViewLogEntryYear {
  final int year;
  final List<DetailViewLogEntryMonth> logItems;
  const DetailViewLogEntryYear({required this.year, required this.logItems});
}

class DetailViewLogEntryMonth {
  final int monthOfYear;
  final List<DetailViewLogEntryDay> logItems;
  const DetailViewLogEntryMonth(
      {required this.monthOfYear, required this.logItems});
}

class DetailViewLogEntryDay {
  final int dayOfMonth;
  final List<DetailViewLogEntryItem> logItems;
  const DetailViewLogEntryDay(
      {required this.dayOfMonth, required this.logItems});
}

class DetailViewLogEntryItem {
  final Goal goal;
  final DateTime time;
  final GoalLogEntry entry;
  final bool archived;

  // This could be either an AddStatusIntentionLogEntry or an AddStatusReflectionLogEntry
  final GoalLogEntry? statusNote;

  const DetailViewLogEntryItem({
    required this.goal,
    required this.entry,
    this.archived = false,
    required this.time,
    this.statusNote,
  });
}

class GoalHistoryWidget extends StatelessWidget {
  final List<DetailViewLogEntryYear> yearItems;
  final String goalId;
  final VoidCallback onRefresh;
  const GoalHistoryWidget(
      {super.key,
      required this.yearItems,
      required this.goalId,
      required this.onRefresh});

  Widget _renderDay(
      DetailViewLogEntryYear yearItem,
      DetailViewLogEntryMonth monthItem,
      DetailViewLogEntryDay dayItem,
      bool first,
      bool last) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(right: uiUnit(2)),
            child: Container(
                width: uiUnit(6),
                child: Column(
                  children: [
                    Text(
                      "${dayItem.dayOfMonth}".padLeft(2, "0"),
                      textAlign: TextAlign.center,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: uiUnit(2)),
                        child: Container(
                          width: 0,
                          color: darkElementColor,
                        ),
                      ),
                    )
                  ],
                )),
          ),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final item in dayItem.logItems)
                ConstrainedBox(
                    constraints: BoxConstraints(minHeight: uiUnit(8)),
                    child: switch (item.entry) {
                      NoteLogEntry() => NoteCard(
                          key: ValueKey((item.entry as NoteLogEntry).id),
                          goal: item.goal,
                          entry: item.entry as NoteLogEntry,
                          isChildGoal: item.goal.id != this.goalId,
                          onRefresh: this.onRefresh,
                        ),
                      StatusLogEntry() => StatusCard(
                          key: ValueKey(
                              "${item.entry.id}${item.archived ? '-archive' : (item.entry as StatusLogEntry).endTime == item.time ? '-end' : '-creation'}"),
                          goal: item.goal,
                          entry: item.entry as StatusLogEntry,
                          isChildGoal: item.goal.id != this.goalId,
                          archived: item.archived,
                          time: item.time,
                          isStatusEnd: (item.entry as StatusLogEntry).endTime ==
                              item.time,
                          text: item.statusNote is AddStatusReflectionLogEntry
                              ? (item.statusNote as AddStatusReflectionLogEntry)
                                  .reflectionText
                              : item.statusNote is AddStatusIntentionLogEntry
                                  ? (item.statusNote
                                          as AddStatusIntentionLogEntry)
                                      .intentionText
                                  : null,
                        ),
                      _ => throw UnimplementedError()
                    })
            ]),
          ),
        ],
      ),
    );
  }

  Widget renderMonth(DetailViewLogEntryYear yearItem,
      DetailViewLogEntryMonth monthItem, bool first, bool last) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Container(
                width: uiUnit(10),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM')
                          .format(DateTime(2022, monthItem.monthOfYear)),
                      textAlign: TextAlign.center,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: uiUnit(2)),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                                right: BorderSide(
                              color: darkElementColor,
                              width: uiUnit(0.5),
                            )),
                          ),
                        ),
                      ),
                    )
                  ],
                )),
          ),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (i, dayItem) in monthItem.logItems.indexed)
                _renderDay(yearItem, monthItem, dayItem, i == 0,
                    i == monthItem.logItems.length - 1),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final yearItem in this.yearItems)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Container(
                      width: uiUnit(10),
                      child: Column(
                        children: [
                          Text(
                            "${yearItem.year}",
                            textAlign: TextAlign.center,
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: uiUnit(2)),
                              child: Container(
                                width: uiUnit(.5),
                                color: darkElementColor,
                              ),
                            ),
                          )
                        ],
                      )),
                ),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final (i, monthItem) in yearItem.logItems.indexed)
                      renderMonth(yearItem, monthItem, i == 0,
                          i == yearItem.logItems.length - 1),
                  ]),
                ),
              ],
            ),
          ),
      ],
    );
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

  Widget parentBreadcrumbs(Goal supergoal) {
    Goal? curGoal = supergoal;
    final widgets = <Widget>[];

    while (curGoal != null) {
      widgets.add(Breadcrumb(goal: curGoal));
      widgets.add(const Icon(Icons.chevron_right));
      curGoal = curGoal.superGoals.firstOrNull;
    }
    widgets.removeLast();

    return Row(children: widgets.reversed.toList());
  }

  Widget breadcrumbs() {
    if (this.widget.goal.superGoals.isEmpty) {
      return Row(children: [AddParentBreadcrumb(goalId: widget.goal.id)]);
    }

    final List<Widget> widgets = [];
    for (final supergoal in this.widget.goal.superGoals) {
      widgets.add(parentBreadcrumbs(supergoal));
    }

    return Column(children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    final isDebugMode = ref.watch(debugProvider);
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final List<DetailViewLogEntryItem> logItems = [];
    for (final goal in [...widget.goal.subGoals, widget.goal]) {
      logItems.addAll(goal.log.map((entry) => DetailViewLogEntryItem(
          goal: goal, entry: entry, time: entry.creationTime)));
    }
    final textTheme = Theme.of(context).textTheme;
    final historyLog = _computeHistoryLog(worldContext, logItems);
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
                                AppContext.of(context).syncClient.modifyGoal(
                                    GoalDelta(
                                        id: widget.goal.id,
                                        text: _textController.text));
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
              GoalActionsContext.overrideWith(context,
                  child: widget.hoverActionsBuilder(widget.goal.id),
                  onPrint: (_) {
                printGoal((pw.Document doc) async {
                  final font = await PdfGoogleFonts.jostRegular();
                  doc.addPage(pw.MultiPage(
                    pageFormat: PdfPageFormat.letter,
                    build: (context) => [
                      pw.Header(
                          level: 1,
                          text: widget.goal.text,
                          textStyle: pw.TextStyle(fontSize: 24, font: font)),
                      for (final item
                          in _computeFlatHistoryLog(worldContext, logItems))
                        if (item.entry is NoteLogEntry) ...[
                          if (item.goal.id != widget.goal.id)
                            pw.Header(
                                level: 2,
                                margin: pw.EdgeInsets.zero,
                                padding: pw.EdgeInsets.fromLTRB(0, 18, 0, 0),
                                text: item.goal.text,
                                textStyle: pw.TextStyle(
                                    font: font,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 18)),
                          pw.Divider(),
                          ...(item.entry as NoteLogEntry)
                              .text
                              .split("\n")
                              .map((line) => pw.Text(line,
                                  style: pw.TextStyle(font: font)))
                              .toList(),
                        ]
                    ],
                  ));
                });
              }),
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
        AddNoteCard(goalId: this.widget.goal.id),
        SizedBox(height: uiUnit()),
        GoalHistoryWidget(
            yearItems: historyLog,
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
