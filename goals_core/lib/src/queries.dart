import 'dart:math';

import 'package:goals_types/goals_types.dart';
import 'package:collection/collection.dart' show IterableZip;

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

_visitAncestors(Map<String, Goal> goalMap, String? head,
    bool Function(String, List<String> path) visit,
    {Set<String>? seenIds, List<String> tail = const []}) {
  if (head == null) {
    return;
  }
  seenIds = seenIds ?? {head};

  final headGoal = goalMap[head];
  if (headGoal == null) {
    throw Exception('Parent goal not found: $head');
  }
  for (final superGoal in headGoal.superGoals) {
    if (visit(superGoal.id, tail)) {
      return;
    }
    _visitAncestors(goalMap, superGoal.id, visit,
        seenIds: seenIds, tail: [...tail, head]);
  }
}

_findAncestors(Map<String, Goal> goalMap, Set<String> frontierIds,
    Map<String, int> seenIds,
    [depth = 1]) {
  if (frontierIds.isEmpty) {
    return;
  }

  Set<String> newFrontierIds = {};
  for (final parentId in frontierIds) {
    final parent = goalMap[parentId];
    if (parent == null) {
      throw Exception('Parent goal not found: $parentId');
    }
    for (final superGoal in parent.superGoals) {
      if (!seenIds.containsKey(superGoal.id)) {
        newFrontierIds.add(superGoal.id);
        seenIds[superGoal.id] = depth;
      }
    }
  }

  return _findAncestors(goalMap, newFrontierIds, seenIds, depth + 1);
}

Iterable<String> getGoalsToAncestor(Map<String, Goal> goalMap, String goalId,
    {String? ancestorId}) {
  List<String>? result;
  _visitAncestors(goalMap, goalId, (String id, List<String> path) {
    if (id == ancestorId) {
      result = path;
      return true;
    }
    return false;
  });

  return result ?? [];
}

List<Goal> findCommonPrefix(
    Iterable<Goal> ancestryA, Iterable<Goal> ancestryB) {
  final result = <Goal>[];
  for (final [ancestorA, ancestorB] in IterableZip([ancestryA, ancestryB])) {
    if (ancestorA.id == ancestorB.id) {
      result.add(ancestorA);
    } else {
      break;
    }
  }
  return result;
}

Map<String, int> _intersectKeys(Map<String, int> a, Map<String, int> b) {
  final result = <String, int>{};
  for (final key in a.keys) {
    if (b.containsKey(key)) {
      result[key] = max(a[key]!, b[key]!);
    }
  }
  return result;
}

String? findLatestCommonAncestor(
    Map<String, Goal> goalMap, Iterable<Goal> goals) {
  if (goals.isEmpty) {
    return null;
  }

  Map<String, int>? commonAncestryOverlap;

  for (final goal in goals) {
    final ancestors = <String, int>{goal.id: 0};
    _findAncestors(goalMap, {goal.id}, ancestors);

    if (commonAncestryOverlap == null) {
      commonAncestryOverlap = ancestors;
      continue;
    }

    commonAncestryOverlap = _intersectKeys(commonAncestryOverlap, ancestors);
  }

  if (commonAncestryOverlap!.isEmpty) {
    return null;
  }

  int maxDepth = 0;
  String? maxDepthAncestorId;
  for (final entry in commonAncestryOverlap.entries) {
    if (entry.value > maxDepth || maxDepthAncestorId == null) {
      maxDepth = entry.value;
      maxDepthAncestorId = entry.key;
    }
  }

  return maxDepthAncestorId;
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

    // If a goal is a child of a snoozed goal.
    if (transitivelySnoozedGoals.containsKey(goal.id)) {
      continue;
    }
    result[goal.id] = goal;
  }

  // find latest common ancestor of all goals
  final latestCommonAncestor = findLatestCommonAncestor(goalMap, result.values);

  if (latestCommonAncestor != null) {
    result[latestCommonAncestor] = goalMap[latestCommonAncestor]!;
  }

  // fill all parents up to that ancestor
  final goalsToAdd = <String>{};
  for (final goal in result.values) {
    getGoalsToAncestor(goalMap, goal.id, ancestorId: latestCommonAncestor)
        .forEach((goalId) {
      goalsToAdd.add(goalId);
    });
  }

  for (final goalId in goalsToAdd) {
    result[goalId] = goalMap[goalId]!;
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
