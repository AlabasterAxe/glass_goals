import 'dart:math';

import 'package:goals_core/src/sync/sync_client.dart';
import 'package:goals_types/goals_types.dart';
import 'package:collection/collection.dart'
    show IterableExtension, IterableNullableExtension, IterableZip;

import '../model.dart' show Goal, WorldContext;
import 'util/date_utils.dart';

Map<String, Goal> getTransitiveSubGoals(
    Map<String, Goal> goalMap, String rootGoalId,
    {bool Function(Goal)? predicate}) {
  // don't apply the predicate to the root goal
  final result = <String, Goal>{rootGoalId: goalMap[rootGoalId]!};
  final queue = <String>[...goalMap[rootGoalId]!.subGoalIds];
  while (queue.isNotEmpty) {
    final goalId = queue.removeLast();
    final goal = goalMap[goalId];

    if (goal == null || predicate != null && !predicate(goal)) {
      continue;
    }
    result[goalId] = goal;
    queue.addAll(goal.subGoalIds);
  }
  return result;
}

Map<String, Goal> getGoalsMatchingPredicate(
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

enum TraversalDecision {
  /// indicates that we should continue traversing normally
  continueTraversal,

  /// indicates that we should stop traversing completely
  stopTraversal,

  /// indicates that we should not visit this node's children or parents (depending on traversal direction)
  dontRecurse,
}

/// This function returns whether or not the traversal should stop. If true, the traversal will stop.
bool _traverseDown(
  Map<String, Goal> goalMap,
  String? rootGoalId, {
  required TraversalDecision? Function(String, List<String> path) onVisit,
  Function(String goalId, List<String> path)? onDepart,
  required List<String> tail,
  int Function(Goal goalA, Goal goalB)? childTraversalComparator,
}) {
  if (rootGoalId == null) {
    return false;
  }

  final headGoal = goalMap[rootGoalId];
  // if the goal doesn't exist in the map we'll just skip it.
  if (headGoal == null) {
    return false;
  }

  final decision = onVisit(headGoal.id, tail);
  if (decision == TraversalDecision.dontRecurse) {
    onDepart?.call(headGoal.id, tail);
    return false;
  } else if (decision == TraversalDecision.stopTraversal) {
    onDepart?.call(headGoal.id, tail);
    return true;
  }
  final newTail = [...tail, rootGoalId];
  for (final subGoalIds in childTraversalComparator != null
      ? headGoal.subGoalIds
          .map((e) => goalMap[e])
          .whereNotNull()
          .sorted(childTraversalComparator)
          .map((e) => e.id)
      : headGoal.subGoalIds) {
    if (_traverseDown(goalMap, subGoalIds,
        onVisit: onVisit,
        onDepart: onDepart,
        tail: newTail,
        childTraversalComparator: childTraversalComparator)) {
      return true;
    }
  }
  onDepart?.call(headGoal.id, tail);

  return false;
}

traverseDown(
  Map<String, Goal> goalMap,
  String? rootGoalId, {
  /// callback for when a goal is visited. By default, the traversal will
  /// continue but traversing the children can be stopped by returning
  /// [TraversalDecision.dontRecurse] and the entire traversal can be stopped by
  /// returning [TraversalDecision.stopTraversal]
  required TraversalDecision? Function(String goalId, List<String> path)
      onVisit,

  /// callback for after a goals children have been visited
  Function(String goalId, List<String> path)? onDepart,
  int Function(Goal goalA, Goal goalB)? childTraversalComparator,
}) {
  _traverseDown(goalMap, rootGoalId,
      onVisit: onVisit,
      onDepart: onDepart,
      tail: [],
      childTraversalComparator: childTraversalComparator);
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
    for (final superGoalId in parent.superGoalIds) {
      if (!seenIds.containsKey(superGoalId)) {
        newFrontierIds.add(superGoalId);
        seenIds[superGoalId] = depth;
      }
    }
  }

  return _findAncestors(goalMap, newFrontierIds, seenIds, depth + 1);
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

  int? minDepth;
  String? maxDepthAncestorId;
  for (final entry in commonAncestryOverlap.entries) {
    if (minDepth == null ||
        entry.value < minDepth ||
        maxDepthAncestorId == null) {
      minDepth = entry.value;
      maxDepthAncestorId = entry.key;
    }
  }

  return maxDepthAncestorId;
}

/// The logic for goals requiring attention is as follows:
///  - Show all active tasks
///  - Don't show tasks if any of their children are marked active
///  - Show tasks that don't currently have a setting (e.g. they were previously active and have become inactive)
///  - don't show any tasks under a snoozed task.
Map<String, Goal> getGoalsRequiringAttention(
    WorldContext context, Map<String, Goal> goalMap) {
  /// The logic for goals requiring attention is as follows:
  ///  - Show all active tasks
  ///  - Don't show tasks if any of their children are marked active
  ///  - Show tasks that don't currently have a setting (i.e. they were previously active and have become inactive)
  final result = <String, Goal>{};
  final unscheduledRootGoals = getGoalsMatchingPredicate(goalMap, (Goal goal) {
    final status = getGoalStatus(context, goal);
    bool hasSuperGoalsInMap = false;
    for (final superGoalId in goal.superGoalIds) {
      if (goalMap.containsKey(superGoalId)) {
        hasSuperGoalsInMap = true;
        break;
      }
    }
    return status.status == null && !hasSuperGoalsInMap;
  });

  final transitivelyUnscheduledGoals = unscheduledRootGoals.values
      .map((goal) => getTransitiveSubGoals(goalMap, goal.id,
          predicate: (goal) => getGoalStatus(context, goal).status == null))
      .fold(<String, Goal>{}, (value, element) => value..addAll(element));

  result.addAll(transitivelyUnscheduledGoals);

  final completedAndArchivedGoals =
      getGoalsMatchingPredicate(goalMap, (Goal goal) {
    final status = getGoalStatus(context, goal);
    return [GoalStatus.done, GoalStatus.archived].contains(status.status);
  });

  for (final goalId in completedAndArchivedGoals.keys) {
    final transitiveGoals = getTransitiveSubGoals(goalMap, goalId);
    for (final subgoalId in transitiveGoals.keys) {
      result.remove(subgoalId);
    }
  }

  return result;
}

Map<String, Goal> getPreviouslyActiveGoals(
    WorldContext context, Map<String, Goal> goalMap) {
  final previouslyActiveGoals = getGoalsMatchingPredicate(goalMap, (Goal goal) {
    if (getGoalStatus(context, goal).status != null) {
      return false;
    }

    Set<String> archivedStatuses = {};
    for (final entry in goal.log.reversed) {
      if (entry is ArchiveStatusLogEntry) {
        archivedStatuses.add(entry.id);
      }
      if (entry is StatusLogEntry &&
          entry.status == GoalStatus.active &&
          !archivedStatuses.contains(entry.id)) {
        return true;
      }
    }
    return false;
  });

  for (final goal in goalMap.values) {
    if (getGoalStatus(context, goal).status == GoalStatus.pending) {
      for (final snoozedSubgoal
          in getTransitiveSubGoals(goalMap, goal.id).keys) {
        previouslyActiveGoals.remove(snoozedSubgoal);
      }
    }
  }
  return previouslyActiveGoals;
}

Map<String, Goal> getGoalsForDateRange(
    WorldContext context, Map<String, Goal> goalMap,
    [DateTime? start,
    DateTime? end,
    DateTime? smallerWindowStart,
    DateTime? smallerWindowEnd]) {
  final result = <String, Goal>{};
  final activeGoalsWithinWindow =
      getGoalsMatchingPredicate(goalMap, (Goal goal) {
    final status = getGoalStatus(context, goal);
    if (status.status != GoalStatus.active) {
      return false;
    }
    if (smallerWindowStart != null &&
        smallerWindowEnd != null &&
        statusIsBetweenDatesInclusive(
            status, smallerWindowStart, smallerWindowEnd)) {
      return false;
    }

    return statusIsBetweenDatesInclusive(status, start, end);
  });

  final snoozedGoalsEndingWithinWindow =
      getGoalsMatchingPredicate(goalMap, (Goal goal) {
    final status = getGoalStatus(context, goal);
    if (status.status != GoalStatus.pending) {
      return false;
    }
    if (smallerWindowStart != null &&
        smallerWindowEnd != null &&
        status.endTime != null &&
        status.endTime!.isAfter(smallerWindowStart) &&
        status.endTime!.isBefore(smallerWindowEnd)) {
      return false;
    }

    return status.endTime != null &&
        (start == null || status.endTime!.isAfter(start)) &&
        (end == null || status.endTime!.isBefore(end));
  });

  result.addAll(activeGoalsWithinWindow);
  result.addAll(snoozedGoalsEndingWithinWindow);

  return result;
}

// Currently, current goal status is just a function of time.
StatusLogEntry getGoalStatus(WorldContext context, Goal goal) {
  final now = context.time;

  Set<String> archivedStatuses = {};
  for (final entry in (goal.log
    ..sort((a, b) => b.creationTime.compareTo(a.creationTime)))) {
    if (entry is StatusLogEntry &&
        !archivedStatuses.contains(entry.id) &&
        (entry.startTime == null || entry.startTime!.isBefore(now)) &&
        (entry.endTime == null || entry.endTime!.isAfter(now))) {
      return entry;
    }
    if (entry is ArchiveStatusLogEntry) {
      archivedStatuses.add(entry.id);
    }
  }
  return StatusLogEntry(
      id: 'default-status', creationTime: DateTime(1970, 1, 1), status: null);
}

getPriorityComparator(WorldContext context) {
  return (Goal goalA, Goal goalB) => getGoalPriority(context, goalA)
      .compareTo(getGoalPriority(context, goalB));
}

double getGoalPriority(WorldContext context, Goal goal) {
  final PriorityLogEntry? explicitPriority = goal.log
      .whereType<PriorityLogEntry>()
      .sorted((a, b) => b.creationTime.compareTo(a.creationTime))
      .firstOrNull;

  if (explicitPriority?.priority != null) {
    return explicitPriority!.priority!;
  }

  return explicitPriority?.creationTime.millisecondsSinceEpoch.toDouble() ??
      goal.creationTime.millisecondsSinceEpoch.toDouble();
}

StatusLogEntry? goalHasStatus(
    WorldContext context, Goal goal, GoalStatus status) {
  final statusLogEntry = getGoalStatus(context, goal);
  if (statusLogEntry.status == status) {
    return statusLogEntry;
  }
  return null;
}

// should I be accepting the world context here and using it to determine the current time?
MakeAnchorLogEntry? isAnchor(Goal? goal) {
  if (goal == null) {
    return null;
  }

  for (final entry in goal.log) {
    if (entry is MakeAnchorLogEntry) {
      return entry;
    }

    if (entry is ClearAnchorLogEntry) {
      return null;
    }
  }

  return null;
}
