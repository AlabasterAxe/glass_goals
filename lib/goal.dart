import 'package:flutter/material.dart';

import 'model.dart';
import 'styles.dart';

class GoalWidget extends StatelessWidget {
  final Goal goal;

  const GoalWidget(this.goal, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Center(
              child: Text(
                "To ${goal.text}",
              ),
            )),
        Positioned.fill(
          child: goal.subGoals.isNotEmpty
              ? PageView(
                  children: goal.subGoals
                      .map((e) =>
                          Center(child: Text(e.text, style: mainTextStyle)))
                      .toList(),
                )
              : const Center(
                  child: Text('Nothin\' to it but to do it.'),
                ),
        ),
      ],
    );
  }
}
