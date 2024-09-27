import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart';
import 'package:goals_web/goal_viewer/goal_actions_context.dart';

import '../styles.dart';
import 'goal_viewer_constants.dart';
import 'providers.dart';

class GoalSeparator extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final List<String> prevGoalPath;
  final List<String> nextGoalPath;
  final bool isFirst;
  final Function(GoalDragDetails)? onDropGoal;
  const GoalSeparator({
    super.key,
    required this.goalMap,
    required this.prevGoalPath,
    required this.nextGoalPath,
    this.onDropGoal,
    required this.isFirst,
  });

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _hovered = false;
  bool _dragHovered = false;

  bool _hoverUpdateSent = false;

  @override
  initState() {
    super.initState();
    hoverEventStream.stream.listen((event) {
      if (pathsMatch(event, this.widget.nextGoalPath) ||
          pathsMatch(event, this.widget.prevGoalPath)) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      } else {
        _hoverUpdateSent = false;

        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<GoalDragDetails>(
      onAcceptWithDetails: (deets) {
        this.widget.onDropGoal?.call(deets.data);
        setState(() {
          _dragHovered = false;
        });
      },
      onMove: (details) {
        setState(() {
          _dragHovered = true;
          hoverEventStream.add(null);
        });
      },
      onLeave: (data) {
        setState(() {
          _dragHovered = false;
        });
      },
      builder: (_, __, ___) => Padding(
        padding:
            EdgeInsets.only(left: uiUnit(4) * (widget.nextGoalPath.length - 2)),
        child: Stack(
          children: [
            SizedBox(
              height: uiUnit(2),
              child: Center(
                child: Container(
                  color: this._hovered || this._dragHovered
                      ? darkElementColor
                      : Colors.transparent,
                  height: 2,
                ),
              ),
            ),
            if (!this.widget.isFirst)
              Positioned(
                child: MouseRegion(
                    onHover: (event) {
                      if (this.widget.prevGoalPath.isNotEmpty &&
                          this.widget.prevGoalPath.last !=
                              NEW_GOAL_PLACEHOLDER) {
                        hoverEventStream.add(this.widget.prevGoalPath);
                      }
                    },
                    child: Container(
                      color: pathsMatch(
                              hoverEventStream.value, this.widget.prevGoalPath)
                          ? emphasizedLightBackground
                          : Colors.transparent,
                    )),
                top: 0,
                left: 0,
                right: 0,
                height: uiUnit(),
              ),
            Positioned(
              child: MouseRegion(
                onHover: (event) {
                  if (!this._hoverUpdateSent &&
                      this.widget.nextGoalPath.isNotEmpty &&
                      this.widget.nextGoalPath.last != NEW_GOAL_PLACEHOLDER) {
                    hoverEventStream.add(this.widget.nextGoalPath);
                  }
                },
                child: Container(
                  color: pathsMatch(
                          hoverEventStream.value, this.widget.nextGoalPath)
                      ? emphasizedLightBackground
                      : Colors.transparent,
                ),
              ),
              bottom: 0,
              left: 0,
              right: 0,
              height: uiUnit(),
            ),
          ],
        ),
      ),
    );
  }
}
