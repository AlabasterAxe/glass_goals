import 'package:collection/collection.dart';

class Goal {
  String id;
  String text;
  late List<Goal> subGoals;
  String? parentId;

  Goal({required this.text, required this.id, subGoals, this.parentId}) {
    this.subGoals = subGoals ?? [];
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
