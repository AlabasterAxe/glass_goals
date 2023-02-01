import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal;

class GoalItemWidget extends StatelessWidget {
  final Goal goal;
  final bool selected;
  final Function(bool? value) onSelected;
  const GoalItemWidget(
      {super.key,
      required this.goal,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: selected, onChanged: onSelected),
        Text(goal.text),
      ],
    );
  }
}
