import 'package:goals_types/goals_types.dart' show GoalLogEntry;

class Goal {
  final String id;

  // These fields are intentionally not final to allow references to stay valid
  String text;
  final List<String> subGoalIds = [];
  final List<String> superGoalIds = [];

  /// A log of changes to this goal. This is guaranteed to be
  /// sorted from newest to oldest.
  final List<GoalLogEntry> log = [];
  final DateTime creationTime;

  Goal({
    required this.text,
    required this.id,
    List<Goal>? subGoals,
    List<Goal>? superGoals,
    required this.creationTime,
  }) {
    if (subGoals != null) {
      this.subGoalIds.addAll(subGoals.map((goal) => goal.id));
    }
    if (superGoals != null) {
      this.superGoalIds.addAll(superGoals.map((goal) => goal.id));
    }
  }

  /// Modifies the subgoal list of this goal to update the goal with the given id.
  /// or add it if it doesn't exist.
  addSubGoal(String goalId) {
    if (!subGoalIds.contains(goalId)) {
      subGoalIds.add(goalId);
    }
  }

  addSuperGoal(String goalId) {
    if (!superGoalIds.contains(goalId)) {
      superGoalIds.add(goalId);
    }
  }

  removeSubGoal(String goalId) {
    subGoalIds.remove(goalId);
  }

  hasParent(String goalId) {
    return superGoalIds.contains(goalId);
  }

  removeSuperGoal(String goalId) {
    superGoalIds.remove(goalId);
  }
}

class WorldContext {
  final DateTime time;

  WorldContext({required this.time});

  static WorldContext now() => WorldContext(time: DateTime.now());
}
