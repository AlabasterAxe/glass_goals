import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal, WorldContext, getGoalStatus;
import 'package:goals_core/sync.dart';
import 'package:goals_core/util.dart'
    show
        DateTimeExtension,
        isWithinCalendarMonth,
        isWithinCalendarWeek,
        isWithinCalendarYear,
        isWithinDay,
        isWithinQuarter;
import 'package:goals_web/app_context.dart';
import 'package:goals_web/goal_viewer/providers.dart'
    show debugProvider, worldContextProvider;
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

String getActiveDateString(DateTime now, StatusLogEntry status) {
  if (isWithinDay(now, status)) {
    return 'Today';
  } else if (isWithinCalendarWeek(now, status)) {
    return 'This Week';
  } else if (isWithinCalendarMonth(now, status)) {
    return 'This Month';
  } else if (isWithinQuarter(now, status)) {
    return 'This Quarter';
  } else if (isWithinCalendarYear(now, status)) {
    return 'This Year';
  } else if (status.endTime != null) {
    return 'Until ${DateFormat.yMd().format(status.endTime!)}';
  } else {
    return 'Ongoing';
  }
}

String getSnoozedDateString(DateTime now, StatusLogEntry status) {
  if (status.endTime?.isBefore(now.startOfDay.subtract(const Duration(seconds: 1))) ==
      true) {
    return DateFormat.yMd().format(status.endTime!);
  } else if (status.endTime?.isBefore(now.endOfDay.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Later Today';
  } else if (status.endTime?.isBefore(now.add(const Duration(days: 1)).endOfDay) ==
      true) {
    return 'Tomorrow';
  } else if (status.endTime?.isBefore(now.endOfWeek.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Later This Week';
  } else if (status.endTime?.isBefore(now.add(const Duration(days: 7)).endOfWeek.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Next Week';
  } else if (status.endTime?.isBefore(now.endOfMonth.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Later This Month';
  } else if (status.endTime?.isBefore(now.endOfMonth
          .add(const Duration(days: 1))
          .endOfMonth
          .subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Next Month';
  } else if (status.endTime
          ?.isBefore(now.endOfQuarter.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Later This Quarter';
  } else if (status.endTime
          ?.isBefore(now.endOfQuarter.add(const Duration(days: 1)).endOfQuarter.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Next Quarter';
  } else if (status.endTime?.isBefore(now.endOfYear.subtract(const Duration(seconds: 1))) == true) {
    return 'Later This Year';
  } else if (status.endTime != null) {
    return DateFormat.yMd().format(status.endTime!);
  } else {
    // Snoozing forever doesn't really make sense, but we'll render it as forever
    return 'Forever';
  }
}

String getGoalStatusStringSince(WorldContext context, StatusLogEntry status) {
  switch (status.status) {
    case GoalStatus.active:
      return "Active since ${status.endTime != null ? DateFormat.yMd().format(status.endTime!) : 'the beginning of time'}";
    case GoalStatus.done:
      return 'Done since ${status.endTime != null ? DateFormat.yMd().format(status.endTime!) : 'the beginning of time'}}';
    case GoalStatus.archived:
      return 'Archived';
    case GoalStatus.pending:
      return "Snoozed since ${status.endTime != null ? DateFormat.yMd().format(status.endTime!) : 'the beginning of time'}";
    case null:
      return 'To Do';
  }
}

String getVerboseGoalStatusString(WorldContext context, StatusLogEntry status) {
  switch (status.status) {
    case GoalStatus.active:
      return "Active ${status.endTime != null ? 'until ${DateFormat.yMd().format(status.endTime!)}' : 'forever'}";
    case GoalStatus.done:
      return 'Done${status.endTime != null ? ' until ${getSnoozedDateString(context.time, status)}' : ''}';
    case GoalStatus.archived:
      return 'Archived';
    case GoalStatus.pending:
      return "Snoozed until ${DateFormat.yMd().format(status.endTime!)}";
    case null:
      return 'To Do';
  }
}

String getGoalStatusString(WorldContext context, StatusLogEntry status) {
  switch (status.status) {
    case GoalStatus.active:
      return getActiveDateString(context.time, status);
    case GoalStatus.done:
      return 'Done';
    case GoalStatus.archived:
      return 'Archived';
    case GoalStatus.pending:
      return getSnoozedDateString(context.time, status);
    case null:
      return 'To Do';
  }
}

Color getGoalStatusBackgroundColor(StatusLogEntry status) {
  switch (status.status) {
    case GoalStatus.active:
      return paleGreenColor;
    case GoalStatus.done:
      return paleBlueColor;
    case GoalStatus.archived:
      return paleGreyColor;
    case GoalStatus.pending:
      return yellowColor;
    case null:
      return palePurpleColor;
  }
}

Color getGoalStatusTextColor(StatusLogEntry status) {
  switch (status.status) {
    case GoalStatus.active:
      return darkGreenColor;
    case GoalStatus.done:
      return darkBlueColor;
    case GoalStatus.archived:
      return darkGreyColor;
    case GoalStatus.pending:
      return darkBrownColor;
    case null:
      return darkPurpleColor;
  }
}

/// Status Chip is a "dumb" Widget that just accepts a StatusLogEntry and displays it.
class StatusChip extends ConsumerWidget {
  final StatusLogEntry entry;
  final String goalId;
  final bool showArchiveButton;
  final bool until;
  final bool since;
  const StatusChip({
    super.key,
    required this.entry,
    required this.goalId,
    required this.showArchiveButton,
    this.until = false,
    this.since = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldContext = ref.watch(worldContextProvider);
    final isDebugMode = ref.watch(debugProvider);

    return Container(
      decoration: BoxDecoration(
        color: getGoalStatusBackgroundColor(this.entry),
        borderRadius: BorderRadius.circular(1),
      ),
      padding: EdgeInsets.only(
        top: uiUnit() / 2,
        bottom: uiUnit() / 2,
        left: uiUnit(),
        right: uiUnit() / 2,
      ),
      child: Row(
        children: [
          isDebugMode
              ? Tooltip(
                  message:
                      '${this.entry.startTime != null ? DateFormat.yMd().format(this.entry.startTime!) : 'The Big Bang'} - ${this.entry.endTime != null ? DateFormat.yMd().format(this.entry.endTime!) : 'The Heat Death of the Universe'}',
                  child: Text(
                    until
                        ? getVerboseGoalStatusString(worldContext, this.entry)
                        : since
                            ? getGoalStatusStringSince(worldContext, this.entry)
                            : getGoalStatusString(worldContext, this.entry),
                    style: smallTextStyle.copyWith(
                        color: getGoalStatusTextColor(this.entry)),
                  ),
                )
              : Text(
                  until
                      ? getVerboseGoalStatusString(worldContext, this.entry)
                      : since
                          ? getGoalStatusStringSince(worldContext, this.entry)
                          : getGoalStatusString(worldContext, this.entry),
                  style: smallTextStyle.copyWith(
                      color: getGoalStatusTextColor(this.entry)),
                ),
          SizedBox(width: uiUnit() / 2),
          if (entry.status != null && this.showArchiveButton)
            SizedBox(
              width: 18.0,
              height: 18.0,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16.0),
                onPressed: () {
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: this.goalId,
                      logEntry: ArchiveStatusLogEntry(
                          creationTime: DateTime.now(), id: entry.id)));
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Current Status Chip is a "smart" Widget that accepts a goal and
/// looks up the current status of that goal according to the World context.
class CurrentStatusChip extends ConsumerWidget {
  final Goal goal;

  const CurrentStatusChip({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldContext = ref.watch(worldContextProvider);
    final goalStatus = getGoalStatus(worldContext, goal);

    return StatusChip(
        entry: goalStatus, goalId: goal.id, showArchiveButton: true);
  }
}
