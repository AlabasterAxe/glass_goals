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
    show BuildContext, Icon, Row, Text, Widget;
import 'package:goals_core/model.dart' show Goal, getGoalStatus;
import 'package:goals_core/sync.dart' show GoalStatus;
import 'package:goals_core/util.dart' show DateTimeExtension;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'providers.dart';

class HoverActionsWidget extends ConsumerStatefulWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  final Function() onArchive;
  final Function() onDone;
  final Function(DateTime? endDate) onSnooze;
  final Function() onClearSelection;
  final Function(DateTime? endDate) onActive;
  final Map<String, Goal> goalMap;
  final MainAxisSize mainAxisSize;
  const HoverActionsWidget({
    super.key,
    required this.onMerge,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onSnooze,
    required this.onActive,
    required this.onClearSelection,
    required this.goalMap,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  ConsumerState<HoverActionsWidget> createState() => _HoverActionsWidgetState();
}

class _HoverActionsWidgetState extends ConsumerState<HoverActionsWidget> {
  final _snoozeMenuController = MenuController();
  final _activateMenuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final worldContext = ref.watch(worldContextProvider);

    bool allArchived = true;
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
          message: 'Schedule',
          child: MenuAnchor(
            controller: _activateMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('For an hour'),
                onPressed: () => widget
                    .onActive(DateTime.now().add(const Duration(hours: 1))),
              ),
              MenuItemButton(
                  child: const Text('Later Today...'),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      widget.onActive(DateTime.now().copyWith(
                          hour: time.hour, minute: time.minute, second: 0));
                    }
                  }),
              MenuItemButton(
                child: const Text('Today'),
                onPressed: () => widget.onActive(DateTime.now().endOfDay),
              ),
              MenuItemButton(
                child: const Text('This Week'),
                onPressed: () => widget.onActive(DateTime.now().endOfWeek),
              ),
              MenuItemButton(
                child: const Text('This Month'),
                onPressed: () => widget.onActive(DateTime.now().endOfMonth),
              ),
              MenuItemButton(
                child: const Text('This Quarter'),
                onPressed: () => widget.onActive(DateTime.now().endOfQuarter),
              ),
              MenuItemButton(
                child: const Text('This Year'),
                onPressed: () => widget.onActive(DateTime.now().endOfYear),
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
                      widget.onActive(date.endOfDay);
                    }
                  }),
              MenuItemButton(
                child: const Text('Forever'),
                onPressed: () => widget.onActive(null),
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
          message: 'Snooze',
          child: MenuAnchor(
            controller: _snoozeMenuController,
            menuChildren: [
              MenuItemButton(
                child: const Text('An hour'),
                onPressed: () => widget
                    .onSnooze(DateTime.now().add(const Duration(hours: 1))),
              ),
              MenuItemButton(
                  child: const Text('Later Today...'),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      widget.onSnooze(DateTime.now().copyWith(
                          hour: time.hour, minute: time.minute, second: 0));
                    }
                  }),
              MenuItemButton(
                child: const Text('Tomorrow'),
                onPressed: () {
                  widget.onSnooze(
                      DateTime.now().add(const Duration(days: 1)).startOfDay);
                },
              ),
              MenuItemButton(
                child: const Text('Next week'),
                onPressed: () {
                  widget.onSnooze(DateTime.now().endOfWeek);
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
                      widget.onSnooze(day);
                    }
                  }),
            ],
            child: IconButton(
              icon: const Icon(Icons.snooze),
              onPressed: () {
                _snoozeMenuController.open();
              },
            ),
          ),
        ),
        Tooltip(
          message: 'Mark Done',
          child: IconButton(
            icon: const Icon(Icons.done_outline_rounded),
            onPressed: widget.onDone,
          ),
        ),
        allArchived
            ? Tooltip(
                message: 'Unarchive',
                child: IconButton(
                  icon: const Icon(Icons.unarchive),
                  onPressed: widget.onUnarchive,
                ),
              )
            : Tooltip(
                message: 'Archive',
                child: IconButton(
                  icon: const Icon(Icons.archive),
                  onPressed: widget.onArchive,
                ),
              ),
        Tooltip(
          message: 'Merge',
          child: IconButton(
            icon: const Icon(Icons.merge),
            onPressed: selectedGoals.length > 1 ? widget.onMerge : null,
          ),
        ),
      ],
    );
  }
}
