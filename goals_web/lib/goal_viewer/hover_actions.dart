import 'dart:ui' show Locale, VoidCallback;

import 'package:flutter/material.dart'
    show
        IconButton,
        Icons,
        MenuAnchor,
        MenuController,
        MenuItemButton,
        TimeOfDay,
        Tooltip,
        showDatePicker,
        showTimePicker;
import 'package:flutter/rendering.dart'
    show EdgeInsets, MainAxisAlignment, MainAxisSize;
import 'package:flutter/widgets.dart'
    show BuildContext, Icon, IconData, Row, SizedBox, Text, Widget;
import 'package:goals_core/model.dart' show Goal, getGoalStatus;
import 'package:goals_core/sync.dart' show GoalStatus;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:goals_web/styles.dart' show darkElementColor;
import 'package:goals_web/widgets/target_icon.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
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

  Widget _button(
      {IconData? icon, required VoidCallback onPressed, Widget? iconWidget}) {
    assert(icon != null || iconWidget != null);
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: icon != null
            ? Icon(icon, color: darkElementColor, size: 24)
            : iconWidget!,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final worldContext = ref.watch(worldContextProvider);

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
            child: _button(
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
            child: _button(
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
          message: 'Mark Done...',
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
            child: _button(
              icon: Icons.done_outline_rounded,
              onPressed: () {
                _doneMenuController.open();
              },
            ),
          ),
        ),
        allArchived
            ? Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Unarchive',
                child: _button(
                  icon: Icons.unarchive,
                  onPressed: () => onUnarchive(widget.goalId),
                ),
              )
            : Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Archive',
                child: _button(
                  icon: Icons.archive,
                  onPressed: () => onArchive(widget.goalId),
                ),
              ),
      ],
    );
  }
}
