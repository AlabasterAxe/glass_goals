import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        GoalPath,
        TraversalDecision,
        WorldContext,
        getGoalStatus,
        getGoalsMatchingPredicate,
        getPriorityComparator,
        getTransitiveSubGoals,
        hasSummary,
        isAnchor,
        traverseDown;
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
        RemoveParentLogEntry,
        SetParentLogEntry,
        SetSummaryEntry,
        StatusLogEntry;
import 'package:goals_core/util.dart' show formatTime;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/common/constants.dart';
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;
import 'package:goals_web/goal_viewer/goal_actions_context.dart';
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/goal_viewer/goal_note.dart' show NoteCard;
import 'package:goals_web/goal_viewer/goal_search_modal.dart'
    show GoalSearchModal, GoalSelectedResult;
import 'package:goals_web/goal_viewer/goal_summary.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/pending_goal_viewer.dart';
import 'package:goals_web/goal_viewer/printed_goal.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/scheduled_goals_v2.dart';
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:goals_web/intents.dart';
import 'package:goals_web/styles.dart'
    show
        darkElementColor,
        deepRedColor,
        lightBackground,
        mainTextStyle,
        palePinkColor,
        uiUnit;
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' show HTMLToPdf;
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' show ExtensionSet, markdownToHtml;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl;
import 'package:uuid/uuid.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'flattened_goal_tree.dart' show FlattenedGoalTree;

List<DetailViewLogEntryYear> _computeHistoryLog(
    WorldContext worldContext,
    Map<String, Goal> goalMap,
    String rootGoalId,
    List<DetailViewLogEntryItem> log) {
  final List<DetailViewLogEntryYear> result = [];
  for (final item
      in _computeFlatHistoryLog(worldContext, rootGoalId, log, goalMap)) {
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
    WorldContext worldContext,
    String rootGoalId,
    List<DetailViewLogEntryItem> log,
    Map<String, Goal> goalMap) {
  Map<String, DetailViewLogEntryItem> items = {};
  log.sort((a, b) => a.entry.creationTime.compareTo(b.entry.creationTime));
  for (final item in log) {
    final entry = item.entry;
    switch (entry) {
      case NoteLogEntry():
        if (item.path.goalId != rootGoalId) {
          continue;
        }
        final originalNoteDate = items[entry.id]?.entry.creationTime;
        items[entry.id] = DetailViewLogEntryItem(
            entry: entry,
            time: originalNoteDate ?? entry.creationTime,
            path: item.path);
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
            path: item.path,
          );
        }
      case StatusLogEntry():
        items["${entry.id}-creation"] = DetailViewLogEntryItem(
          entry: entry,
          path: item.path,
          time: entry.creationTime,
        );

        // Only add an end entry for active statuses.
        if (entry.endTime != null &&
            entry.endTime != entry.creationTime &&
            entry.endTime!.isBefore(worldContext.time) &&
            entry.status == GoalStatus.active &&
            // If the goal is archived or done by the time the status ends, don't show the end entry.
            ![GoalStatus.archived, GoalStatus.done].contains(getGoalStatus(
                    WorldContext(time: entry.endTime!),
                    goalMap[item.path.goalId]!)
                .status)) {
          items["${entry.id}-end"] = DetailViewLogEntryItem(
            entry: entry,
            path: item.path,
            time: entry.endTime!,
          );
        }

        break;
      case AddStatusIntentionLogEntry():
        final existingItem = items["${entry.statusId}-creation"];
        if (existingItem != null && existingItem.entry is StatusLogEntry) {
          items["${entry.statusId}-creation"] = DetailViewLogEntryItem(
            entry: existingItem.entry,
            path: existingItem.path,
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
            path: existingItem.path,
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

List<DetailViewLogEntryItem> _getFlattenedSummaryItems(
    WorldContext context, Map<String, Goal> goalMap, String rootGoalId) {
  final priorityComparator = getPriorityComparator(context);
  final List<DetailViewLogEntryItem> flattenedGoals = [];
  traverseDown(
    goalMap,
    rootGoalId,
    onVisit: (goalId, path) {
      final summary = hasSummary(goalMap[goalId]!);
      if (summary != null) {
        flattenedGoals.add(DetailViewLogEntryItem(
          path: path,
          entry: summary,
          time: summary.creationTime,
          depth: path.length,
        ));
      }

      if (summary?.text == null) {
        return TraversalDecision.dontRecurse;
      }
    },
    childTraversalComparator: priorityComparator,
  );

  return flattenedGoals;
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
                showDialog(
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
                                    onGoalSelected: (newParentId) {
                                      AppContext.of(context)
                                          .syncClient
                                          .modifyGoal(GoalDelta(
                                              id: widget.goalId,
                                              logEntry: SetParentLogEntry(
                                                  id: Uuid().v4(),
                                                  creationTime: DateTime.now(),
                                                  parentId: newParentId)));
                                      return GoalSelectedResult.close;
                                    },
                                  )),
                        ));
              }),
        ],
      ),
    );
  }
}

class StatusCard extends ConsumerStatefulWidget {
  final GoalPath path;
  final Map<String, Goal> goalMap;
  final StatusLogEntry entry;
  final bool archived;
  final bool isStatusEnd;
  final DateTime time;
  final String? text;
  final bool isChildGoal;
  const StatusCard({
    super.key,
    required this.path,
    required this.goalMap,
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
        id: widget.path.goalId,
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
    final noteType = this.widget.isStatusEnd ||
            this.widget.entry.status == GoalStatus.done
        ? "reflection"
        : [GoalStatus.pending, GoalStatus.active]
                    .contains(this.widget.entry.status) &&
                this.widget.entry.id ==
                    getGoalStatus(
                            worldContext, widget.goalMap[widget.path.goalId]!)
                        .id
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
                  Breadcrumb(
                      path: this.widget.path, goalMap: this.widget.goalMap),
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
              goalId: this.widget.path.goalId,
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
                    child: Actions(
                      actions: {
                        AcceptMultiLineTextIntent: CallbackAction(
                            onInvoke: (_) => _saveNote(noteType)),
                        CancelIntent:
                            CallbackAction(onInvoke: (_) => _discardEdit()),
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

class GoalDetail extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  final HoverActionsBuilder hoverActionsBuilder;
  final GoalPath path;
  const GoalDetail({
    super.key,
    required this.goalMap,
    required this.hoverActionsBuilder,
    required this.path,
  });

  @override
  ConsumerState<GoalDetail> createState() => _GoalDetailState();

  Goal get goal => this.goalMap[this.path.goalId]!;
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
  final GoalPath path;
  final DateTime time;
  final GoalLogEntry entry;
  final bool archived;
  final int depth;

  // This could be either an AddStatusIntentionLogEntry or an AddStatusReflectionLogEntry
  final GoalLogEntry? statusNote;

  const DetailViewLogEntryItem({
    required this.path,
    required this.entry,
    this.archived = false,
    required this.time,
    this.statusNote,
    this.depth = 0,
  });
}

class GoalHistoryWidget extends StatelessWidget {
  final List<DetailViewLogEntryYear> yearItems;
  final GoalPath path;
  final VoidCallback onRefresh;
  final Map<String, Goal> goalMap;
  const GoalHistoryWidget({
    super.key,
    required this.yearItems,
    required this.path,
    required this.onRefresh,
    required this.goalMap,
  });

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
                if (!(item.entry is NoteLogEntry) ||
                    (item.path.goalId == this.path.goalId))
                  ConstrainedBox(
                      key: ValueKey(item.entry is StatusLogEntry
                          ? "${item.entry.id}${item.archived ? '-archive' : (item.entry as StatusLogEntry).endTime == item.time ? '-end' : '-creation'}"
                          : item.entry.id),
                      constraints: BoxConstraints(minHeight: uiUnit(8)),
                      child: switch (item.entry) {
                        NoteLogEntry entry => Padding(
                            padding: EdgeInsets.only(bottom: uiUnit(4)),
                            child: NoteCard(
                              path: item.path,
                              goalMap: goalMap,
                              textEntry: entry,
                              isChildGoal: item.path.goalId != this.path.goalId,
                              onRefresh: this.onRefresh,
                            ),
                          ),
                        StatusLogEntry entry => StatusCard(
                            path: item.path,
                            entry: entry,
                            isChildGoal: item.path.goalId != this.path.goalId,
                            goalMap: goalMap,
                            archived: item.archived,
                            time: item.time,
                            isStatusEnd: entry.endTime == item.time,
                            text: item.statusNote is AddStatusReflectionLogEntry
                                ? (item.statusNote
                                        as AddStatusReflectionLogEntry)
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
  bool _editing = false;
  late final _textController =
      TextEditingController(text: widget.goalMap[widget.path.goalId]!.text);
  final FocusNode _focusNode = FocusNode();
  PendingGoalViewMode _viewMode = PendingGoalViewMode.tree;

  @override
  void initState() {
    super.initState();
    final pendingGoalViewModeString = Hive.box(UI_STATE_BOX).get(
        viewModeBoxKey(widget.path.goalId),
        defaultValue: PendingGoalViewMode.tree.name);

    try {
      _viewMode = PendingGoalViewMode.values.byName(pendingGoalViewModeString);
    } catch (_) {
      _viewMode = PendingGoalViewMode.tree;
    }
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.goal.text != oldWidget.goal.text) {
      _textController.text = widget.goal.text;
    }

    final pendingGoalViewModeString = Hive.box(UI_STATE_BOX).get(
        viewModeBoxKey(widget.goal.id),
        defaultValue: PendingGoalViewMode.tree.name);

    setState(() {
      try {
        _viewMode =
            PendingGoalViewMode.values.byName(pendingGoalViewModeString);
      } catch (_) {
        _viewMode = PendingGoalViewMode.tree;
      }
    });
  }

  Widget parentBreadcrumbs() {
    if (this.widget.goal.superGoalIds.isEmpty) {
      return Row(children: [AddParentBreadcrumb(goalId: widget.goal.id)]);
    }

    final List<Widget> widgets = [];
    for (final superGoalId in this.widget.goal.superGoalIds) {
      widgets.add(ParentBreadcrumb(
        path: GoalPath([...widget.path, 'ui:breadcrumb', superGoalId]),
        goalMap: widget.goalMap,
        onRemove: () {
          AppContext.of(context).syncClient.modifyGoal(GoalDelta(
              id: this.widget.goal.id,
              logEntry: RemoveParentLogEntry(
                  id: Uuid().v4(),
                  creationTime: DateTime.now(),
                  parentId: superGoalId)));
        },
      ));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  _printGoal(WorldContext worldContext) async {
    printGoal((pw.Document doc) async {
      final font = await PdfGoogleFonts.jostRegular();
      final fontBold = await PdfGoogleFonts.jostBold();
      final fontItalic = await PdfGoogleFonts.jostItalic();
      final widgets = [
        pw.Header(
            level: 1,
            text: widget.goal.text,
            textStyle: pw.TextStyle(fontSize: 24, font: font)),
        for (final item in _getFlattenedSummaryItems(
            worldContext, this.widget.goalMap, this.widget.goal.id))
          if (item.entry is SetSummaryEntry)
            pw.Padding(
              padding: pw.EdgeInsets.only(left: item.depth * 10.0),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (item.path.goalId != widget.path.goalId)
                    pw.Header(
                        level: 2,
                        margin: pw.EdgeInsets.zero,
                        padding: pw.EdgeInsets.only(top: 18),
                        text: widget.goalMap[item.path.goalId]!.text,
                        textStyle: pw.TextStyle(
                            font: font,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 18)),
                  pw.Divider(),
                  ...(await HTMLToPdf().convert(
                      markdownToHtml(
                          (item.entry as SetSummaryEntry).text ??
                              "Something went wrong.",
                          extensionSet: ExtensionSet.gitHubWeb),
                      fontResolver: (_, bold, italic) {
                    if (bold) return fontBold;
                    if (italic) return fontItalic;
                    return font;
                  })),
                ],
              ),
            ),
      ];
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        build: (context) => widgets,
      ));
    });
  }

  List<Widget> getModeChildren(WorldContext worldContext) {
    switch (this._viewMode) {
      case PendingGoalViewMode.schedule:
        return [
          ScheduledGoalsV2(
            goalMap: getTransitiveSubGoals(this.widget.goalMap, widget.goal.id)
              ..remove(widget.goal.id),
            path: [...this.widget.path, this.widget.goal.id],
          )
        ];
      case PendingGoalViewMode.tree:
        final subgoalMap = getGoalsMatchingPredicate(widget.goalMap, (goal) {
          final status = getGoalStatus(worldContext, goal);
          return status.status != GoalStatus.archived &&
              status.status != GoalStatus.done;
        });
        return [
          FlattenedGoalTree(
            goalMap: subgoalMap,
            rootGoalIds: widget.goal.subGoalIds
                .where((g) => subgoalMap.containsKey(g))
                .toList(),
            hoverActionsBuilder: widget.hoverActionsBuilder,
            path: this.widget.path,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;

    final textTheme = Theme.of(context).textTheme;

    final isNarrow = MediaQuery.of(context).size.width < 600;

    final isDebugMode = ref.watch(debugProvider);
    final List<DetailViewLogEntryItem> logItems = [];
    for (final goalId in [...widget.goal.subGoalIds, widget.goal.id]) {
      final goal = widget.goalMap[goalId];
      if (goal == null) {
        continue;
      }
      logItems.addAll(goal.log.map((entry) => DetailViewLogEntryItem(
          path: GoalPath([...widget.path, goal.id]),
          entry: entry,
          time: entry.creationTime)));
    }
    final historyLog = _computeHistoryLog(
        worldContext, widget.goalMap, this.widget.goal.id, logItems);
    final goalSummary = hasSummary(widget.goal);

    return Padding(
      padding: EdgeInsets.all(uiUnit(2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isNarrow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editing
                          ? Actions(
                              actions: {
                                CancelIntent: CallbackAction(
                                    onInvoke: (_) => setState(() {
                                          _editing = false;
                                        })),
                              },
                              child: IntrinsicWidth(
                                child: TextField(
                                  autocorrect: false,
                                  controller: _textController,
                                  decoration: null,
                                  style: textTheme.headlineMedium,
                                  onEditingComplete: () {
                                    AppContext.of(context)
                                        .syncClient
                                        .modifyGoal(GoalDelta(
                                            id: widget.goal.id,
                                            text: _textController.text));
                                    setState(() {
                                      _editing = false;
                                    });
                                  },
                                  onTapOutside: (_) {
                                    AppContext.of(context)
                                        .syncClient
                                        .modifyGoal(GoalDelta(
                                            id: widget.goal.id,
                                            text: _textController.text));
                                    setState(() {
                                      _editing = false;
                                    });
                                  },
                                  focusNode: _focusNode,
                                ),
                              ),
                            )
                          : Flexible(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.text,
                                child: GestureDetector(
                                  onTap: _editing
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
                            ),
                      SizedBox(width: uiUnit(2)),
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: CurrentStatusChip(goal: widget.goal),
                      ),
                      SizedBox(width: uiUnit(2)),
                      GoalActionsContext.overrideWith(context,
                          child: widget.hoverActionsBuilder(
                              ['ui:detail', widget.goal.id]), onPrint: (_) {
                        this._printGoal(worldContext);
                      }),
                    ]),
              ),
              PendingGoalViewModePicker(
                  onModeChanged: (mode) {
                    Hive.box(UI_STATE_BOX)
                        .put(viewModeBoxKey(widget.goal.id), mode.name);
                    setState(() {
                      this._viewMode = mode;
                    });
                  },
                  mode: this._viewMode),
            ],
          ),
        parentBreadcrumbs(),
        SizedBox(height: uiUnit(2)),
        ...getModeChildren(worldContext),
        SizedBox(height: uiUnit(2)),
        if (goalSummary != null) ...[
          Text('Summary', style: textTheme.headlineSmall),
          SizedBox(height: uiUnit(1)),
          GoalSummary(path: widget.path, goalMap: widget.goalMap),
        ],
        Text('History', style: textTheme.headlineSmall),
        SizedBox(height: uiUnit(1)),
        AddNoteCard(goalId: this.widget.goal.id),
        SizedBox(height: uiUnit()),
        GoalHistoryWidget(
            yearItems: historyLog,
            path: this.widget.path,
            goalMap: this.widget.goalMap,
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
