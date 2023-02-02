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
  for (final goal in goalMap.values) {
    if (goal.activeUntil == null) {
      continue;
    }

    final activeUntil = DateTime.parse(goal.activeUntil!);
    if (activeUntil.isBefore(DateTime.now())) {
      continue;
    }

    if (result == null ||
        activeUntil.isBefore(DateTime.parse(result.activeUntil!))) {
      result = goal;
    }
  }

  return result;
}

bool isGoalActive(Goal goal) {
  return goal.activeUntil != null &&
      DateTime.parse(goal.activeUntil!).isAfter(DateTime.now());
}
