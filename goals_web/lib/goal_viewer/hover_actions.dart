import 'dart:ui' show Locale;

import 'package:flutter/material.dart'
    show
        Colors,
        Dialog,
        Icons,
        MenuAnchor,
        MenuController,
        MenuItemButton,
        TimeOfDay,
        Tooltip,
        showDatePicker,
        showDialog,
        showTimePicker;
import 'package:flutter/painting.dart' show FractionalOffset;
import 'package:flutter/rendering.dart' show MainAxisAlignment, MainAxisSize;
import 'package:flutter/widgets.dart'
    show BuildContext, Row, StreamBuilder, Text, Widget;
import 'package:goals_core/model.dart'
    show Goal, getGoalStatus, getTransitiveSubGoals;
import 'package:goals_core/sync.dart'
    show AddParentLogEntry, GoalDelta, GoalStatus;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/goal_search_modal.dart';
import 'package:goals_web/styles.dart';
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:goals_web/widgets/target_icon.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'package:uuid/uuid.dart';

import 'goal_actions_context.dart';
import 'providers.dart';

typedef HoverActionsBuilder = Widget Function(String? goalId);

class HoverActionsWidget extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  final MainAxisSize mainAxisSize;

  /// If this HoverActionsWidget is associated with a specific goal
  /// you can supply that goal's id here.
  final String? goalId;

  const HoverActionsWidget({
    super.key,
    required this.goalMap,
    this.mainAxisSize = MainAxisSize.min,
    this.goalId,
  });

  @override
  ConsumerState<HoverActionsWidget> createState() => _HoverActionsWidgetState();
}

const _TOOLTIP_DELAY = Duration(milliseconds: 200);

class _HoverActionsWidgetState extends ConsumerState<HoverActionsWidget> {
  final _snoozeMenuController = MenuController();
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

    bool allArchived = selectedGoals.isNotEmpty;
    for (final selectedGoalId in selectedGoals) {
      if (widget.goalMap.containsKey(selectedGoalId) &&
          getGoalStatus(worldContext, widget.goalMap[selectedGoalId]!).status !=
              GoalStatus.archived) {
        allArchived = false;
        break;
      }
    }
    return Row(
      mainAxisSize: widget.mainAxisSize,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Tooltip(
          waitDuration: _TOOLTIP_DELAY,
          showDuration: Duration.zero,
          message: 'Add existing goal...',
          child: GlassGoalsIconButton(
              icon: Icons.play_for_work,
              onPressed: () async {
                final newChildId = await showDialog(
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
                                final modalMap = snapshot.data ?? Map();
                                final goal = modalMap[widget.goalId];
                                for (final subGoal in goal?.subGoals ?? []) {
                                  modalMap.remove(subGoal.id);
                                }
                                return GoalSearchModal(
                                  goalMap: snapshot.data ?? Map(),
                                );
                              }),
                        ));
                if (newChildId != null) {
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: newChildId,
                      logEntry: AddParentLogEntry(
                          id: Uuid().v4(),
                          creationTime: DateTime.now(),
                          parentId: this.widget.goalId)));
                }
              }),
        ),
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
          message: 'Snooze...',
          child: MenuAnchor(
            controller: _snoozeMenuController,
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
                              hour: time.hour, minute: time.minute, second: 0));
                    }
                  }),
              MenuItemButton(
                child: const Text('Tomorrow'),
                onPressed: () {
                  onSnooze(widget.goalId,
                      DateTime.now().add(const Duration(days: 1)).startOfDay);
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
            child: GlassGoalsIconButton(
              icon: Icons.hotel,
              onPressed: () {
                _snoozeMenuController.open();
              },
            ),
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
        allArchived
            ? Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Unarchive',
                child: GlassGoalsIconButton(
                  icon: Icons.unarchive,
                  onPressed: () => onUnarchive(widget.goalId),
                ),
              )
            : Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Archive',
                child: GlassGoalsIconButton(
                  icon: Icons.archive,
                  onPressed: () => onArchive(widget.goalId),
                ),
              ),
      ],
    );
  }
}
