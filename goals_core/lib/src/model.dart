import 'package:goals_types/goals_types.dart' show GoalLogEntry;

class Goal {
  final String id;

  // These fields are intentionally not final to allow references to stay valid
  String text;
  final List<Goal> subGoals = [];
  final List<Goal> superGoals = [];

  /// A log of changes to this goal. This is guaranteed to be
  /// sorted from oldest to newest.
  final List<GoalLogEntry> log = [];
  final DateTime creationTime;

  Goal({
    required this.text,
    required this.id,
    subGoals,
    superGoals,
    required this.creationTime,
  }) {
    if (subGoals != null) {
      this.subGoals.addAll(subGoals);
    }
    if (superGoals != null) {
      this.superGoals.addAll(superGoals);
    }
  }

  /// Modifies the subgoal list of this goal to update the goal with the given id.
  /// or add it if it doesn't exist.
  addOrReplaceSubGoal(Goal goal) {
    int index = subGoals.indexWhere((g) => g.id == goal.id);

    if (index == -1) {
      subGoals.add(goal);
    } else {
      subGoals[index] = goal;
    }
  }

  addOrReplaceSuperGoal(Goal goal) {
    int index = superGoals.indexWhere((g) => g.id == goal.id);

    if (index == -1) {
      superGoals.add(goal);
    } else {
      superGoals[index] = goal;
    }
  }

  removeSubGoal(String id) {
    subGoals.removeWhere((g) => g.id == id);
  }

  removeSuperGoal(String id) {
    superGoals.removeWhere((g) => g.id == id);
  }
}

class WorldContext {
  final DateTime time;

  WorldContext({required this.time});

  static WorldContext now() => WorldContext(time: DateTime.now());
}
