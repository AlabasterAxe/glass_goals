import 'package:goals_types/goals_types.dart';

import '../model.dart' show Goal;

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

Goal? getActiveGoalExpiringSoonest(Map<String, Goal> goalMap) {
  Goal? result;
  StatusLogEntry? resultActiveStatus;
  for (final goal in goalMap.values) {
    final activeStatus = isGoalActive(goal);
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

StatusLogEntry? getGoalStatus(Goal goal) {
  final now = DateTime.now();
  final possibleStatuses = goal.statusLog
      .where((s) =>
          (s.startTime == null || s.startTime!.isBefore(now)) &&
          (s.endTime == null || s.endTime!.isAfter(now)))
      .toList();
  if (possibleStatuses.isEmpty) {
    return null;
  }
  possibleStatuses.sort((a, b) {
    if (b.startTime == null && a.startTime == null) {
      return 0;
    }

    if (b.startTime == null) {
      return -1;
    }
    if (a.startTime == null) {
      return 1;
    }
    return b.startTime!.compareTo(a.startTime!);
  });
  return possibleStatuses.first;
}

StatusLogEntry? isGoalActive(Goal goal) {
  final statusLogEntry = getGoalStatus(goal);
  if (statusLogEntry?.status == GoalStatus.active) {
    return statusLogEntry;
  }
  return null;
}
