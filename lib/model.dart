class Goal {
  final String id;
  final String text;
  late final List<Goal> subGoals;

  Goal({required this.text, required this.id, subGoals}) {
    this.subGoals = subGoals ?? [];
  }
}
