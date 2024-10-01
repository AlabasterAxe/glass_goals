import 'dart:async';

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
  final List<String> path;
  const GoalSeparator({
    super.key,
    required this.goalMap,
    required this.prevGoalPath,
    required this.nextGoalPath,
    this.onDropGoal,
    required this.isFirst,
    this.path = const [],
  });

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _dragHovered = false;

  bool _adjacentHover = false;

  late StreamSubscription _hoverEventSubscription;

  @override
  initState() {
    super.initState();

    this._hoverEventSubscription = hoverEventStream.listen((newHoveredPath) {
      if (pathsMatch(newHoveredPath, this.widget.nextGoalPath) ||
          pathsMatch(newHoveredPath, this.widget.prevGoalPath)) {
        setState(() {
          this._adjacentHover = true;
        });
      } else {
        if (this._adjacentHover) {
          setState(() {
            this._adjacentHover = false;
          });
        }
      }
    });
  }

  @override
  dispose() {
    this._hoverEventSubscription.cancel();

    super.dispose();
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
        if (!_dragHovered) {
          setState(() {
            _dragHovered = true;
          });
        }

        if (hoverEventStream.value != null) {
          hoverEventStream.add(null);
        }
      },
      onLeave: (data) {
        if (_dragHovered) {
          setState(() {
            _dragHovered = false;
          });
        }
      },
      builder: (_, __, ___) => Padding(
        padding: EdgeInsets.only(
            left: this._dragHovered
                ? uiUnit(4) *
                    (widget.nextGoalPath.length - (1 + this.widget.path.length))
                : 0),
        child: Stack(
          children: [
            SizedBox(
              height: uiUnit(2),
              child: Center(
                child: Container(
                  color: this._adjacentHover || this._dragHovered
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
                      if (!pathsMatch(hoverEventStream.value,
                              this.widget.prevGoalPath) &&
                          this.widget.prevGoalPath.isNotEmpty &&
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
                  if (!pathsMatch(
                          hoverEventStream.value, this.widget.nextGoalPath) &&
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
