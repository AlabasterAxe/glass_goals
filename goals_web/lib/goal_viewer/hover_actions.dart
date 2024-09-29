import 'dart:ui' show Locale;

import 'package:flutter/material.dart'
    show
        Colors,
        Dialog,
        Icons,
        MenuAnchor,
        MenuController,
        MenuItemButton,
        SubmenuButton,
        TimeOfDay,
        Tooltip,
        showDatePicker,
        showDialog,
        showTimePicker;
import 'package:flutter/painting.dart' show FractionalOffset;
import 'package:flutter/rendering.dart' show CrossAxisAlignment, MainAxisSize;
import 'package:flutter/widgets.dart'
    show BuildContext, Expanded, Icon, Row, StreamBuilder, Text, Widget;
import 'package:goals_core/model.dart'
    show Goal, getGoalStatus, getTransitiveSuperGoals, hasSummary, isAnchor;
import 'package:goals_core/sync.dart'
    show AddParentLogEntry, GoalDelta, GoalStatus;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/goal_search_modal.dart';
import 'package:goals_web/goal_viewer/goal_viewer_constants.dart';
import 'package:goals_web/styles.dart';
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:goals_web/widgets/target_icon.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'package:uuid/uuid.dart';

import 'goal_actions_context.dart';
import 'providers.dart';

typedef HoverActionsBuilder = Widget Function(List<String>? goalId);

class HoverActionsWidget extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  final MainAxisSize mainAxisSize;

  /// If this HoverActionsWidget is associated with a specific goal
  /// you can supply that goal's id here.
  final List<String>? path;

  const HoverActionsWidget({
    super.key,
    required this.goalMap,
    this.mainAxisSize = MainAxisSize.min,
    this.path,
  });

  String? get goalId => path?.last;

  @override
  ConsumerState<HoverActionsWidget> createState() => _HoverActionsWidgetState();
}

const _TOOLTIP_DELAY = Duration(milliseconds: 200);

class _HoverActionsWidgetState extends ConsumerState<HoverActionsWidget> {
  final _moreActionsMenuController = MenuController();
  final _activateMenuController = MenuController();
  final _doneMenuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final selectedGoals =
        ref.watch(selectedGoalsProvider).value ?? selectedGoalsStream.value;
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;

    final onActive = GoalActionsContext.of(context).onActive;
    final onSnooze = GoalActionsContext.of(context).onSnooze;
    final onDone = GoalActionsContext.of(context).onDone;
    final onArchive = GoalActionsContext.of(context).onArchive;
    final onUnarchive = GoalActionsContext.of(context).onUnarchive;
    final onPrint = GoalActionsContext.of(context).onPrint;
    final onExpanded = GoalActionsContext.of(context).onExpanded;
    final onMakeAnchor = GoalActionsContext.of(context).onMakeAnchor;
    final onClearAnchor = GoalActionsContext.of(context).onClearAnchor;
    final onAddSummary = GoalActionsContext.of(context).onAddSummary;
    final onClearSummary = GoalActionsContext.of(context).onClearSummary;

    bool allArchived = selectedGoals.isNotEmpty;
    for (final selectedGoalId in selectedGoals) {
      if (widget.goalMap.containsKey(selectedGoalId) &&
          getGoalStatus(worldContext, widget.goalMap[selectedGoalId]!).status !=
              GoalStatus.archived) {
        allArchived = false;
        break;
      }
    }

    final showAnchorOption = selectedGoals.isEmpty || selectedGoals.length == 1;
    final showClearAnchorOption =
        isAnchor(widget.goalMap[widget.goalId]) != null;
    final goalHasSummary = hasSummary(widget.goalMap[widget.goalId]) != null;
    return Row(
      mainAxisSize: widget.mainAxisSize,
      crossAxisAlignment: widget.mainAxisSize == MainAxisSize.min
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          waitDuration: _TOOLTIP_DELAY,
          showDuration: Duration.zero,
          message: 'Work on this...',
          child: MenuAnchor(
            controller: _activateMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('Today'),
                onPressed: () => onActive(widget.goalId,
                    startTime: DateTime.now().startOfDay,
                    endTime: DateTime.now().endOfDay),
              ),
              MenuItemButton(
                child: const Text('This Week'),
                onPressed: () => onActive(widget.goalId,
                    startTime: DateTime.now().startOfWeek,
                    endTime: DateTime.now().endOfWeek),
              ),
              MenuItemButton(
                child: const Text('This Month'),
                onPressed: () => onActive(widget.goalId,
                    startTime: DateTime.now().startOfMonth,
                    endTime: DateTime.now().endOfMonth),
              ),
              MenuItemButton(
                child: const Text('This Quarter'),
                onPressed: () => onActive(widget.goalId,
                    startTime: DateTime.now().startOfQuarter,
                    endTime: DateTime.now().endOfQuarter),
              ),
              MenuItemButton(
                child: const Text('This Year'),
                onPressed: () => onActive(widget.goalId,
                    startTime: DateTime.now().startOfYear,
                    endTime: DateTime.now().endOfYear),
              ),
              MenuItemButton(
                  child: const Text('Until a future Date...'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      locale: const Locale('en', 'GB'),
                    );
                    if (date != null) {
                      onActive(widget.goalId, endTime: date.endOfDay);
                    }
                  }),
              MenuItemButton(
                child: const Text('Long Term'),
                onPressed: () => onActive(widget.goalId),
              ),
            ],
            child: GlassGoalsIconButton(
                iconWidget: TargetIcon(),
                onPressed: () {
                  _activateMenuController.open();
                }),
          ),
        ),
        Tooltip(
          waitDuration: _TOOLTIP_DELAY,
          showDuration: Duration.zero,
          message: 'Mark Done',
          child: MenuAnchor(
            controller: _doneMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('For Today'),
                onPressed: () => onDone(widget.goalId, DateTime.now().endOfDay),
              ),
              MenuItemButton(
                child: const Text('For This Week'),
                onPressed: () =>
                    onDone(widget.goalId, DateTime.now().endOfWeek),
              ),
              MenuItemButton(
                child: const Text('For This Month'),
                onPressed: () =>
                    onDone(widget.goalId, DateTime.now().endOfMonth),
              ),
              MenuItemButton(
                child: const Text('For This Quarter'),
                onPressed: () =>
                    onDone(widget.goalId, DateTime.now().endOfQuarter),
              ),
              MenuItemButton(
                child: const Text('For This Year'),
                onPressed: () =>
                    onDone(widget.goalId, DateTime.now().endOfYear),
              ),
              MenuItemButton(
                  child: const Text('Until a future Date...'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      locale: const Locale('en', 'GB'),
                    );
                    if (date != null) {
                      onDone(widget.goalId, date.endOfDay);
                    }
                  }),
              MenuItemButton(
                child: const Text('Forever'),
                onPressed: () => onDone(widget.goalId, null),
              ),
            ],
            child: GlassGoalsIconButton(
              icon: Icons.done_outline_rounded,
              onPressed: () => onDone(widget.goalId, null),
              onLongPressed: () => _doneMenuController.open(),
            ),
          ),
        ),
        if (this.widget.goalId != null)
          Tooltip(
              waitDuration: _TOOLTIP_DELAY,
              showDuration: Duration.zero,
              message: 'Add Subgoal',
              child: GlassGoalsIconButton(
                  icon: Icons.add,
                  onPressed: () {
                    onExpanded(widget.path!, expanded: true);
                    textFocusStream
                        .add([...widget.path!, NEW_GOAL_PLACEHOLDER]);
                  })),
        Tooltip(
          waitDuration: _TOOLTIP_DELAY,
          showDuration: Duration.zero,
          message: 'More actions...',
          child: MenuAnchor(
            controller: _moreActionsMenuController,
            menuChildren: [
              MenuItemButton(
                leadingIcon: Icon(Icons.play_for_work),
                child: const Text('Import goals...'),
                onPressed: () async {
                  await showDialog(
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
                                builder: (context, snapshot) {
                                  final Map<String, Goal> modalMap =
                                      snapshot.data != null
                                          ? {...snapshot.data!}
                                          : Map();
                                  final goal = modalMap[widget.goalId];
                                  for (final subGoalId
                                      in goal?.subGoalIds ?? <String>[]) {
                                    modalMap.remove(subGoalId);
                                  }

                                  if (this.widget.goalId != null) {
                                    final goalsToRemove =
                                        getTransitiveSuperGoals(
                                            this.widget.goalMap,
                                            this.widget.goalId!);
                                    for (final goalId in goalsToRemove.keys) {
                                      modalMap.remove(goalId);
                                    }
                                  }
                                  return GoalSearchModal(
                                    goalMap: modalMap,
                                    onGoalSelected: (newChildId) {
                                      AppContext.of(context)
                                          .syncClient
                                          .modifyGoal(GoalDelta(
                                              id: newChildId,
                                              logEntry: AddParentLogEntry(
                                                  id: Uuid().v4(),
                                                  creationTime: DateTime.now(),
                                                  parentId:
                                                      this.widget.goalId)));
                                      return GoalSelectedResult.keepOpen;
                                    },
                                  );
                                }),
                          ));
                },
              ),
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    child: const Text('An hour'),
                    onPressed: () => onSnooze(widget.goalId,
                        DateTime.now().add(const Duration(hours: 1))),
                  ),
                  MenuItemButton(
                      child: const Text('Later Today...'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          onSnooze(
                              widget.goalId,
                              DateTime.now().copyWith(
                                  hour: time.hour,
                                  minute: time.minute,
                                  second: 0));
                        }
                      }),
                  MenuItemButton(
                    child: const Text('Tomorrow'),
                    onPressed: () {
                      onSnooze(
                          widget.goalId,
                          DateTime.now()
                              .add(const Duration(days: 1))
                              .startOfDay);
                    },
                  ),
                  MenuItemButton(
                    child: const Text('Next week'),
                    onPressed: () {
                      onSnooze(widget.goalId, DateTime.now().endOfWeek);
                    },
                  ),
                  MenuItemButton(
                      child: const Text('Future Date...'),
                      onPressed: () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          locale: const Locale('en', 'GB'),
                        );
                        if (day != null) {
                          onSnooze(widget.goalId, day);
                        }
                      }),
                ],
                leadingIcon: Icon(Icons.hotel),
                child: const Text('Snooze goal...'),
              ),
              goalHasSummary && this.widget.goalId != null
                  ? MenuItemButton(
                      child: Text('Remove Summary'),
                      leadingIcon: Icon(Icons.clear),
                      onPressed: () => onClearSummary(this.widget.goalId!),
                    )
                  : MenuItemButton(
                      child: Text('Add Summary'),
                      leadingIcon: Icon(Icons.notes),
                      onPressed: () => onAddSummary(this.widget.goalId!),
                    ),
              allArchived
                  ? MenuItemButton(
                      child: Text('Unarchive'),
                      leadingIcon: Icon(Icons.unarchive),
                      onPressed: () => onUnarchive(widget.goalId),
                    )
                  : MenuItemButton(
                      child: Text('Archive'),
                      leadingIcon: Icon(Icons.archive),
                      onPressed: () => onArchive(widget.goalId),
                    ),
              showClearAnchorOption && this.widget.goalId != null
                  ? MenuItemButton(
                      child: Text('Clear Anchor'),
                      leadingIcon: Icon(Icons.anchor),
                      onPressed: !showAnchorOption
                          ? null
                          : () => onClearAnchor(this.widget.goalId!))
                  : MenuItemButton(
                      child: Text('Make Anchor'),
                      leadingIcon: Icon(Icons.anchor),
                      onPressed: !showAnchorOption
                          ? null
                          : () => onMakeAnchor(this.widget.goalId!)),
              if (onPrint != null)
                MenuItemButton(
                  child: Text('Save as PDF'),
                  leadingIcon: Icon(Icons.picture_as_pdf),
                  onPressed: () => onPrint(this.widget.goalId),
                ),
            ],
            child: GlassGoalsIconButton(
              icon: Icons.more_horiz,
              onPressed: () {
                if (_moreActionsMenuController.isOpen) {
                  _moreActionsMenuController.close();
                } else {
                  _moreActionsMenuController.open();
                }
              },
            ),
          ),
        ),
      ]
          .map((e) => this.widget.mainAxisSize == MainAxisSize.max
              ? Expanded(child: e)
              : e)
          .toList(),
    );
  }
}
