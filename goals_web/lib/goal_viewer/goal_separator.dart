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
  final Function(GoalDragDetails, bool)? onDropGoal;
  final List<String> path;
  final bool pendingShiftSelect;
  final GoalPath? shiftSelectStartPath;
  final GoalPath? shiftSelectEndPath;
  const GoalSeparator({
    super.key,
    required this.goalMap,
    required this.prevGoalPath,
    required this.nextGoalPath,
    this.onDropGoal,
    required this.isFirst,
    this.path = const [],
    this.pendingShiftSelect = false,
    this.shiftSelectStartPath,
    this.shiftSelectEndPath,
  });

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _dragHovered = false;
  bool _topHovered = false;

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
    return Padding(
      padding: EdgeInsets.only(
          left: this._dragHovered
              ? uiUnit(4) *
                  ((_topHovered &&
                                  widget.prevGoalPath.length >
                                      widget.nextGoalPath.length
                              ? widget.prevGoalPath
                              : widget.nextGoalPath)
                          .length -
                      (this.widget.path.length))
              : 0),
      child: Stack(
        children: [
          SizedBox(
            height: uiUnit(2),
            child: Center(
              child: Container(
                color: (this.widget.shiftSelectStartPath == null &&
                                this._adjacentHover ||
                            this._dragHovered) ||
                        (pathsMatch(this.widget.shiftSelectStartPath,
                                this.widget.nextGoalPath) ||
                            pathsMatch(this.widget.shiftSelectEndPath,
                                this.widget.prevGoalPath))
                    ? darkElementColor
                    : Colors.transparent,
                height: 2,
              ),
            ),
          ),
          if (!this.widget.isFirst)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: uiUnit(),
              child: DragTarget<GoalDragDetails>(
                onAcceptWithDetails: (details) {
                  if (dragEventProvider.value == DragEventType.start) {
                    this.widget.onDropGoal?.call(details.data, true);
                  }
                  setState(() {
                    _dragHovered = false;
                    _topHovered = false;
                  });
                },
                onMove: (details) {
                  if (!_dragHovered) {
                    setState(() {
                      _dragHovered = true;
                      _topHovered = true;
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
                      _topHovered = true;
                    });
                  }
                },
                builder: (_, __, ___) => MouseRegion(
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
                      color: pathsMatch(hoverEventStream.value,
                                  this.widget.prevGoalPath) ||
                              this.widget.pendingShiftSelect ||
                              pathsMatch(this.widget.shiftSelectStartPath,
                                  this.widget.prevGoalPath)
                          ? emphasizedLightBackground
                          : Colors.transparent,
                    )),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: uiUnit(),
            child: DragTarget<GoalDragDetails>(
                onAcceptWithDetails: (details) {
                  if (dragEventProvider.value == DragEventType.start) {
                    this.widget.onDropGoal?.call(details.data, false);
                  }
                  setState(() {
                    _dragHovered = false;
                    _topHovered = false;
                  });
                },
                onMove: (details) {
                  if (!_dragHovered) {
                    setState(() {
                      _dragHovered = true;
                      _topHovered = false;
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
                      _topHovered = false;
                    });
                  }
                },
                builder: (_, __, ___) => MouseRegion(
                      onHover: (event) {
                        if (!pathsMatch(hoverEventStream.value,
                                this.widget.nextGoalPath) &&
                            this.widget.nextGoalPath.isNotEmpty &&
                            this.widget.nextGoalPath.last !=
                                NEW_GOAL_PLACEHOLDER) {
                          hoverEventStream.add(this.widget.nextGoalPath);
                        }
                      },
                      child: Container(
                        color: pathsMatch(hoverEventStream.value,
                                    this.widget.nextGoalPath) ||
                                this.widget.pendingShiftSelect ||
                                pathsMatch(this.widget.shiftSelectStartPath,
                                    this.widget.prevGoalPath)
                            ? emphasizedLightBackground
                            : Colors.transparent,
                      ),
                    )),
          ),
        ],
      ),
    );
  }
}
