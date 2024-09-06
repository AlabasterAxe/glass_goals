import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart'
    show BuildContext, Center, StatelessWidget, Text, Widget;
import 'package:goals_core/model.dart' show Goal;

class GoalTitle extends StatelessWidget {
  final Goal goal;

  const GoalTitle(this.goal, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        goal.text,
        style: Theme.of(context).textTheme.displayLarge,
      ),
    );
  }
}
