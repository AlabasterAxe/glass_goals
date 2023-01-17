class Goal {
  final String text;
  late final List<Goal> subGoals;

  Goal({required this.text, subGoals}) {
    subGoals = subGoals ?? [];
  }
}
