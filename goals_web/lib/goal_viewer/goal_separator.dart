import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../styles.dart';

class GoalSeparator extends StatefulWidget {
  const GoalSeparator({super.key});

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget(
      onAccept: (_) {
        setState(() {
          _hovered = false;
        });
      },
      onMove: (details) {
        setState(() {
          _hovered = true;
        });
      },
      onLeave: (data) {
        setState(() {
          _hovered = false;
        });
      },
      builder: (_, __, ___) => SizedBox(
        height: uiUnit(2),
        child: Center(
          child: Container(
            color: this._hovered ? darkElementColor : Colors.transparent,
            height: 2,
          ),
        ),
      ),
    );
  }
}
