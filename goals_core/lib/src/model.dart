import 'dart:collection';

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

class GoalPath extends ListMixin<String> {
  final List<String> _path;

  const GoalPath(this._path);

  @override
  int get length => _path.length;

  @override
  set length(int newLength) {
    _path.length = newLength;
  }

  @override
  String operator [](int index) => _path[index];

  @override
  void operator []=(int index, String value) {
    _path[index] = value;
  }

  String get goalId => _path.last;

  String? get parentId {
    if (_path.length <= 1) {
      return null;
    }

    for (int i = _path.length - 2; i >= 0; i--) {
      if (_path[i].startsWith('ui:')) {
        return null;
      } else if (_path[i].startsWith('slice:')) {
        continue;
      } else {
        return _path[i];
      }
    }
  }

  GoalPath get parentPath => GoalPath(_path.sublist(0, _path.length - 1));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GoalPath) return false;
    if (other.length != length) return false;
    for (int i = 0; i < length; i++) {
      if (other[i] != this[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _path.hashCode;
}
