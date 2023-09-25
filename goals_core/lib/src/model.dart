import 'package:goals_types/goals_types.dart' show GoalLogEntry;

class Goal {
  final String id;

  // These fields are intentionally not final to allow references to stay valid
  String text;
  final List<Goal> subGoals = [];
  String? parentId;
  final List<GoalLogEntry> log = [];

  Goal({required this.text, required this.id, subGoals, this.parentId}) {
    if (subGoals != null) {
      this.subGoals.addAll(subGoals);
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

  removeSubGoal(String id) {
    subGoals.removeWhere((g) => g.id == id);
  }
}

class WorldContext {
  final DateTime time;

  WorldContext({required this.time});

  static WorldContext now() => WorldContext(time: DateTime.now());
}
