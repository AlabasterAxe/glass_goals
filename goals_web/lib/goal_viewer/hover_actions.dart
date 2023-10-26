import 'dart:ui' show Locale;

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
import 'package:flutter/rendering.dart' show MainAxisAlignment, MainAxisSize;
import 'package:flutter/widgets.dart'
    show BuildContext, Container, Icon, Row, Text, Widget;
import 'package:goals_core/model.dart' show Goal, getGoalStatus;
import 'package:goals_core/sync.dart' show GoalStatus;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'providers.dart';

typedef HoverActionsBuilder = Widget Function(String? goalId, bool shown);

class HoverActionsWidget extends ConsumerStatefulWidget {
  final Function(String?) onUnarchive;
  final Function(String?) onArchive;
  final Function(String?) onDone;
  final Function(String?, DateTime? endDate) onSnooze;
  final Function(String?, DateTime? endDate) onActive;
  final Map<String, Goal> goalMap;
  final MainAxisSize mainAxisSize;

  /// If this HoverActionsWidget is associated with a specific goal
  /// you can supply that goal's id here.
  final String? goalId;

  const HoverActionsWidget({
    super.key,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onSnooze,
    required this.onActive,
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

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final worldContext = ref.watch(worldContextProvider);

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
          message: 'Schedule',
          child: MenuAnchor(
            controller: _activateMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('For an hour'),
                onPressed: () => widget.onActive(widget.goalId,
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
                      widget.onActive(
                          widget.goalId,
                          DateTime.now().copyWith(
                              hour: time.hour, minute: time.minute, second: 0));
                    }
                  }),
              MenuItemButton(
                child: const Text('Today'),
                onPressed: () =>
                    widget.onActive(widget.goalId, DateTime.now().endOfDay),
              ),
              MenuItemButton(
                child: const Text('This Week'),
                onPressed: () =>
                    widget.onActive(widget.goalId, DateTime.now().endOfWeek),
              ),
              MenuItemButton(
                child: const Text('This Month'),
                onPressed: () =>
                    widget.onActive(widget.goalId, DateTime.now().endOfMonth),
              ),
              MenuItemButton(
                child: const Text('This Quarter'),
                onPressed: () =>
                    widget.onActive(widget.goalId, DateTime.now().endOfQuarter),
              ),
              MenuItemButton(
                child: const Text('This Year'),
                onPressed: () =>
                    widget.onActive(widget.goalId, DateTime.now().endOfYear),
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
                      widget.onActive(widget.goalId, date.endOfDay);
                    }
                  }),
              MenuItemButton(
                child: const Text('Forever'),
                onPressed: () => widget.onActive(widget.goalId, null),
              ),
            ],
            child: IconButton(
              icon: const Icon(Icons.schedule),
              onPressed: () {
                _activateMenuController.open();
              },
            ),
          ),
        ),
        Tooltip(
          waitDuration: _TOOLTIP_DELAY,
          showDuration: Duration.zero,
          message: 'Snooze',
          child: MenuAnchor(
            controller: _snoozeMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('An hour'),
                onPressed: () => widget.onSnooze(widget.goalId,
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
                      widget.onSnooze(
                          widget.goalId,
                          DateTime.now().copyWith(
                              hour: time.hour, minute: time.minute, second: 0));
                    }
                  }),
              MenuItemButton(
                child: const Text('Tomorrow'),
                onPressed: () {
                  widget.onSnooze(widget.goalId,
                      DateTime.now().add(const Duration(days: 1)).startOfDay);
                },
              ),
              MenuItemButton(
                child: const Text('Next week'),
                onPressed: () {
                  widget.onSnooze(widget.goalId, DateTime.now().endOfWeek);
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
                      widget.onSnooze(widget.goalId, day);
                    }
                  }),
            ],
            child: IconButton(
              icon: const Icon(Icons.hotel),
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
          child: IconButton(
            icon: const Icon(Icons.done_outline_rounded),
            onPressed: () => widget.onDone(widget.goalId),
          ),
        ),
        allArchived
            ? Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Unarchive',
                child: IconButton(
                  icon: const Icon(Icons.unarchive),
                  onPressed: () => widget.onUnarchive(widget.goalId),
                ),
              )
            : Tooltip(
                waitDuration: _TOOLTIP_DELAY,
                showDuration: Duration.zero,
                message: 'Archive',
                child: IconButton(
                  icon: const Icon(Icons.archive),
                  onPressed: () => widget.onArchive(widget.goalId),
                ),
              ),
      ],
    );
  }
}
