import 'package:goals_types/goals_types.dart';

import '../model.dart' show Goal, WorldContext;

Map<String, Goal> getTransitiveSubGoals(
    Map<String, Goal> goalMap, String rootGoalId) {
  final result = <String, Goal>{};
  final queue = <Goal>[goalMap[rootGoalId]!];
  while (queue.isNotEmpty) {
    final goal = queue.removeLast();
    result[goal.id] = goal;
    queue.addAll(goal.subGoals);
  }
  return result;
}

Map<String, Goal> getGoalsMatchingPredicate(WorldContext context,
    Map<String, Goal> goalMap, bool Function(Goal) predicate) {
  final result = <String, Goal>{};
  for (final goal in goalMap.values) {
    if (predicate(goal)) {
      result[goal.id] = goal;
    }
  }
  return result;
}

Goal? getActiveGoalExpiringSoonest(
    WorldContext context, Map<String, Goal> goalMap) {
  Goal? result;
  StatusLogEntry? resultActiveStatus;
  for (final goal in goalMap.values) {
    final activeStatus = goalHasStatus(context, goal, GoalStatus.active);
    if (activeStatus == null) {
      continue;
    }

    if ((result == null && resultActiveStatus == null) ||
        activeStatus.endTime != null &&
            (resultActiveStatus!.endTime == null ||
                activeStatus.endTime!.isBefore(resultActiveStatus.endTime!))) {
      result = goal;
      resultActiveStatus = activeStatus;
    }
  }

  return result;
}

Comparator<Goal> activeGoalExpiringSoonestComparator(WorldContext context) {
  return (Goal a, Goal b) {
    if (a.id == b.id) {
      return 0;
    }
    final aStatus = getGoalStatus(context, a);
    final bStatus = getGoalStatus(context, b);
    if (aStatus.status != GoalStatus.active &&
        bStatus.status != GoalStatus.active) {
      return 0;
    }
    if (aStatus.status == GoalStatus.active &&
        bStatus.status != GoalStatus.active) {
      return -1;
    }
    if (bStatus.status == GoalStatus.active &&
        aStatus.status != GoalStatus.active) {
      return 1;
    }
    if (aStatus.endTime == null && bStatus.endTime == null) {
      return 0;
    }
    if (aStatus.endTime == null && bStatus.endTime != null) {
      return 1;
    }
    if (bStatus.endTime == null && aStatus.endTime != null) {
      return -1;
    }
    return aStatus.endTime!.compareTo(bStatus.endTime!);
  };
}

/// The logic for goals requiring attention is as follows:
///  - Show all active tasks
///  - Don't show tasks if any of their children are marked active
///  - Show tasks that don't currently have a setting (i.e. they were previously active and have become inactive)
///  - don't show any tasks under a snoozed task.
Map<String, Goal> getGoalsRequiringAttention(
    WorldContext context, Map<String, Goal> goalMap) {
  /// The logic for goals requiring attention is as follows:
  ///  - Show all active tasks
  ///  - Don't show tasks if any of their children are marked active
  ///  - Show tasks that don't currently have a setting (i.e. they were previously active and have become inactive)
  final result = <String, Goal>{};
  final activeOrUncategorizedGoals =
      getGoalsMatchingPredicate(context, goalMap, (Goal goal) {
    final status = getGoalStatus(context, goal);
    return status.status == null || status.status == GoalStatus.active;
  });

  final snoozedGoals = getGoalsMatchingPredicate(context, goalMap,
      (Goal goal) => getGoalStatus(context, goal).status == GoalStatus.pending);

  final transitivelySnoozedGoals = snoozedGoals.isNotEmpty
      ? snoozedGoals.values
          .map((goal) => getTransitiveSubGoals(goalMap, goal.id))
          .reduce((value, element) => value..addAll(element))
      : {};

  ///  - Don't show tasks if any of their children are marked active
  for (final goal in activeOrUncategorizedGoals.values) {
    if (goal.subGoals
        .any((g) => activeOrUncategorizedGoals.containsKey(g.id))) {
      continue;
    }

    if (transitivelySnoozedGoals.containsKey(goal.id)) {
      continue;
    }
    result[goal.id] = goal;
  }

  return result;
}

// Currently, current goal status is just a function of time.
StatusLogEntry getGoalStatus(WorldContext context, Goal goal) {
  final now = context.time;
  goal.log;

  final StatusLogEntry? lastStatus = (goal.log
        ..sort((a, b) => b.creationTime.compareTo(a.creationTime)))
      .whereType<StatusLogEntry>()
      .where((entry) =>
          entry.startTime == null ||
          entry.startTime!.isBefore(now) &&
              (entry.endTime == null || entry.endTime!.isAfter(now)))
      .firstOrNull;
  return lastStatus ??
      StatusLogEntry(creationTime: DateTime(1970, 1, 1), status: null);
}

StatusLogEntry? goalHasStatus(
    WorldContext context, Goal goal, GoalStatus status) {
  final statusLogEntry = getGoalStatus(context, goal);
  if (statusLogEntry.status == status) {
    return statusLogEntry;
  }
  return null;
}
