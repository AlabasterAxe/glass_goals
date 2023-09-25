import 'package:flutter/material.dart';
import 'package:goals_core/model.dart';

class GoalDetail extends StatelessWidget {
  final Goal goal;
  const GoalDetail({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(child: Text(goal.text));
  }
}
