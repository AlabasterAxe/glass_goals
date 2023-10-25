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
import 'package:goals_web/goal_viewer/providers.dart' show worldContextProvider;
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
    return DateFormat.yMd().format(status.endTime!);
  } else {
    return 'Ongoing';
  }
}

String getSnoozedDateString(DateTime now, StatusLogEntry status) {
  if (status.endTime?.isBefore(now.endOfDay.subtract(const Duration(seconds: 1))) ==
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
  } else if (status.endTime?.isBefore(now.endOfQuarter.subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Later This Quarter';
  } else if (status.endTime?.isBefore(now.endOfQuarter
          .add(const Duration(days: 1))
          .endOfQuarter
          .subtract(const Duration(seconds: 1))) ==
      true) {
    return 'Next Quarter';
  } else if (status.endTime?.isBefore(now.endOfYear.subtract(const Duration(seconds: 1))) == true) {
    return 'Later This Year';
  } else if (status.endTime != null) {
    return DateFormat.yMd().format(status.endTime!);
  } else {
    return 'Ongoing';
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

class StatusChip extends ConsumerWidget {
  final Goal goal;

  const StatusChip({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldContext = ref.watch(worldContextProvider);
    final goalStatus = getGoalStatus(worldContext, goal);

    return Container(
      decoration: BoxDecoration(
        color: getGoalStatusBackgroundColor(goalStatus),
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
          Text(
            getGoalStatusString(worldContext, goalStatus),
            style: smallTextStyle.copyWith(
                color: getGoalStatusTextColor(goalStatus)),
          ),
          SizedBox(width: uiUnit() / 2),
          goalStatus.status != null
              ? SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 16.0),
                    onPressed: () {
                      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                          id: this.goal.id,
                          logEntry: ArchiveStatusLogEntry(
                              creationTime: DateTime.now(),
                              id: goalStatus.id)));
                    },
                  ),
                )
              : Container()
        ],
      ),
    );
  }
}
