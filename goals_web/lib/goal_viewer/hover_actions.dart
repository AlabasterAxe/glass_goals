import 'package:flutter/material.dart'
    show IconButton, Icons, Tooltip, showDialog;
import 'package:flutter/widgets.dart'
    show BuildContext, Icon, MainAxisAlignment, Row, Text, Widget;
import 'package:goals_core/model.dart' show Goal, getGoalStatus;
import 'package:goals_core/sync.dart' show GoalStatus;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;
import '../widgets/date_picker.dart' show DatePickerDialog;
import 'providers.dart';

class HoverActionsWidget extends ConsumerWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  final Function() onArchive;
  final Function() onDone;
  final Function(DateTime? endDate) onSnooze;
  final Function() onClearSelection;
  final Function(DateTime? endDate) onActive;
  final Map<String, Goal> goalMap;
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final worldContext = ref.watch(worldContextProvider);

    bool allArchived = true;
    for (final selectedGoalId in selectedGoals) {
      if (goalMap.containsKey(selectedGoalId) &&
          getGoalStatus(worldContext, goalMap[selectedGoalId]!).status !=
              GoalStatus.archived) {
        allArchived = false;
        break;
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Tooltip(
          message: 'Merge',
          child: IconButton(
            icon: const Icon(Icons.merge),
            onPressed: onMerge,
          ),
        ),
        allArchived
            ? Tooltip(
                message: 'Unarchive',
                child: IconButton(
                  icon: const Icon(Icons.unarchive),
                  onPressed: onUnarchive,
                ),
              )
            : Tooltip(
                message: 'Archive',
                child: IconButton(
                  icon: const Icon(Icons.archive),
                  onPressed: onArchive,
                ),
              ),
        Tooltip(
          message: 'Activate',
          child: IconButton(
            icon: const Icon(Icons.directions_run),
            onPressed: () async {
              final DateTime? date = await showDialog(
                context: context,
                builder: (context) =>
                    const DatePickerDialog(title: Text('Active Until?')),
              );
              onActive(date);
            },
          ),
        ),
        Tooltip(
          message: 'Snooze',
          child: IconButton(
            icon: const Icon(Icons.snooze),
            onPressed: () async {
              final DateTime? date = await showDialog(
                context: context,
                builder: (context) =>
                    const DatePickerDialog(title: Text('Snooze Until?')),
              );
              onSnooze(date);
            },
          ),
        ),
        Tooltip(
          message: 'Mark Done',
          child: IconButton(
            icon: const Icon(Icons.done),
            onPressed: onDone,
          ),
        ),
        Tooltip(
          message: 'Clear Selection',
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClearSelection,
          ),
        ),
      ],
    );
  }
}
