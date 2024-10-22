import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goals_core/model.dart'
    show Goal, GoalPath, TraversalDecision, traverseDown;
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/goal_viewer/status_chip.dart';

import '../styles.dart';

enum GoalSelectedResult {
  close,
  keepOpen,
}

// this might make it impossible to search for a goal with ">>" in the text.
const _ARROW_SEPARATOR = '>>';

class GoalSearchModal extends StatefulWidget {
  final Map<String, Goal> goalMap;

  final GoalSelectedResult Function(String) onGoalSelected;
  const GoalSearchModal({
    super.key,
    required this.goalMap,
    required this.onGoalSelected,
  });

  @override
  State<GoalSearchModal> createState() => _GoalSearchModalState();
}

class KeyboardFocusableListTile extends StatefulWidget {
  final Goal goal;
  final GoalPath path;
  final bool isFocused;
  final Function()? onTap;
  final Map<String, Goal> goalMap;
  const KeyboardFocusableListTile({
    super.key,
    required this.path,
    required this.isFocused,
    required this.goal,
    required this.goalMap,
    this.onTap,
  });

  @override
  State<KeyboardFocusableListTile> createState() =>
      _KeyboardFocusableListTileState();
}

class _KeyboardFocusableListTileState extends State<KeyboardFocusableListTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: this.widget.isFocused ? Colors.grey.withOpacity(.1) : null,
      child: ListTile(
        selected: this.widget.isFocused,
        title: Row(
          children: [
            PathBreadcrumb(
                path: this.widget.path, goalMap: this.widget.goalMap),
            SizedBox(width: uiUnit()),
            CurrentStatusChip(goal: this.widget.goal),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

class _GoalSearchModalState extends State<GoalSearchModal> {
  final _textController = TextEditingController();
  late final FocusNode _textFocusNode = FocusNode(onKeyEvent: (node, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        this._selectedIndex++;
      });
      return KeyEventResult.handled;
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        this._selectedIndex--;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  String _lastText = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    this._textFocusNode.requestFocus();
    this._textController.addListener(() {
      if (this._textController.text != this._lastText) {
        setState(() {
          this._selectedIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  _selectGoal(String goalId) {
    final result = this.widget.onGoalSelected(goalId);
    if (result == GoalSelectedResult.close) {
      Navigator.pop(context);
    } else {
      this._textFocusNode.requestFocus();
    }
  }

  List<GoalPath> _goalPathSearch(String text) {
    final searchPath = GoalPath(
        text.split(_ARROW_SEPARATOR).map((part) => part.trim()).toList());

    if (searchPath.length == 1) {
      return [];
    }

    final results = <GoalPath>[];
    final roots = this
        .widget
        .goalMap
        .values
        .where((goal) => goal.text.toLowerCase().contains(searchPath[0]))
        .toList();

    for (final root in roots) {
      traverseDown(this.widget.goalMap, root.id,
          onVisit: (String goalId, GoalPath path) {
        final fullGoalPath = GoalPath([...path, goalId]);
        if (fullGoalPath.length > searchPath.length) {
          return TraversalDecision.dontRecurse;
        }
        final visitedGoal = this.widget.goalMap[goalId];

        if (visitedGoal == null) {
          return TraversalDecision.dontRecurse;
        }
        for (final (i, part) in fullGoalPath.indexed) {
          final goalText = this.widget.goalMap[part]!.text.toLowerCase();
          if (!goalText.contains(searchPath[i])) {
            return TraversalDecision.dontRecurse;
          }
        }
        if (fullGoalPath.length == searchPath.length) {
          results.add(fullGoalPath);
          return TraversalDecision.dontRecurse;
        }
        return TraversalDecision.continueTraversal;
      });
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    if (this._textController.text.length == 0) {}
    final results = _textController.text.length == 0
        ? <GoalPath>[]
        : [
            ...this
                .widget
                .goalMap
                .values
                .where((goal) => goal.text
                    .toLowerCase()
                    .contains(_textController.text.toLowerCase()))
                .map((g) => GoalPath([g.id])),
            ...this._goalPathSearch(this._textController.text)
          ];
    final modalWidth = min(MediaQuery.of(context).size.width * .8, 600);
    final wrappedSelectedIndex = this._selectedIndex % results.length;
    return SizedBox(
      width: modalWidth.toDouble(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  suffixIcon: _textController.text.length > 0
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _textController.clear();
                            Navigator.pop(context);
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) {
                  if (results.isNotEmpty) {
                    _selectGoal(results[wrappedSelectedIndex].goalId);
                  }
                },
                focusNode: this._textFocusNode,
                controller: this._textController,
                onChanged: (_) => setState(() {})),
          ),
          SizedBox(
            height: 400,
            child: ListView(primary: true, children: [
              for (final (i, path) in results.indexed)
                KeyboardFocusableListTile(
                  goalMap: this.widget.goalMap,
                  path: path,
                  isFocused: wrappedSelectedIndex == i,
                  onTap: () {
                    _selectGoal(path.goalId);
                  },
                  goal: this.widget.goalMap[path.goalId]!,
                ),
            ]),
          )
        ],
      ),
    );
  }
}
