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

Goal? getActiveGoalExpiringSoonest(
    WorldContext context, Map<String, Goal> goalMap) {
  Goal? result;
  StatusLogEntry? resultActiveStatus;
  for (final goal in goalMap.values) {
    final activeStatus = isGoalActive(context, goal);
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

StatusLogEntry? isGoalActive(WorldContext context, Goal goal) {
  final statusLogEntry = getGoalStatus(context, goal);
  if (statusLogEntry?.status == GoalStatus.active) {
    return statusLogEntry;
  }
  return null;
}
