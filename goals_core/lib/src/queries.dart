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

/// The logic for goals requiring attention is as follows:
///  - Show all active tasks
///  - Don't show tasks if any of their children are marked active
///  - Show tasks that don't currently have a setting (i.e. they were previously active and have become inactive)
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
    return status == null || status.status == GoalStatus.active;
  });

  ///  - Don't show tasks if any of their children are marked active
  for (final goal in activeOrUncategorizedGoals.values) {
    if (goal.subGoals
        .any((g) => activeOrUncategorizedGoals.containsKey(g.id))) {
      continue;
    }
    result[goal.id] = goal;
  }

  return result;
}

// Currently, current goal status is just a function of time.
StatusLogEntry? getGoalStatus(WorldContext context, Goal goal) {
  final now = context.time;
  final possibleStatuses = goal.statusLog
      .where((s) => (s.startTime == null || s.startTime!.isBefore(now)))
      .toList();
  if (possibleStatuses.isEmpty) {
    return null;
  }
  possibleStatuses.sort((a, b) => b.creationTime.compareTo(a.creationTime));

  if (possibleStatuses.first.endTime != null &&
      possibleStatuses.first.endTime!.isBefore(now)) {
    return null;
  }

  return possibleStatuses.first;
}

StatusLogEntry? goalHasStatus(
    WorldContext context, Goal goal, GoalStatus status) {
  final statusLogEntry = getGoalStatus(context, goal);
  if (statusLogEntry?.status == status) {
    return statusLogEntry;
  }
  return null;
}
