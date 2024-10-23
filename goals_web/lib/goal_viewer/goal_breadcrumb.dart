import 'package:flutter/material.dart' show Colors, IconButton, Icons, Ink;
import 'package:flutter/painting.dart'
    show
        CircleBorder,
        EdgeInsets,
        ShapeDecoration,
        TextDecoration,
        TextStyle,
        VoidCallback;
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        GestureDetector,
        Icon,
        MainAxisSize,
        MouseRegion,
        Row,
        SizedBox,
        State,
        StatefulWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal, GoalPath, isAnchor;
import 'package:goals_web/goal_viewer/goal_actions_context.dart';
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

class Breadcrumb extends ConsumerWidget {
  final Map<String, Goal> goalMap;
  final TextStyle? style;
  final GoalPath path;
  const Breadcrumb({
    super.key,
    required this.goalMap,
    this.style,
    required this.path,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          child: Text(goalMap[path.goalId]!.text,
              style: this.style != null
                  ? this.style!.copyWith(decoration: TextDecoration.underline)
                  : TextStyle(decoration: TextDecoration.underline)),
          onTap: () {
            GoalActionsContext.of(context).onFocused(path);
          }),
    );
  }
}

class PathBreadcrumb extends StatefulWidget {
  final GoalPath renderedPath;
  final GoalPath contextPath;
  final Map<String, Goal> goalMap;
  const PathBreadcrumb({
    super.key,
    required this.renderedPath,
    required this.goalMap,
    this.contextPath = const GoalPath([]),
  });

  @override
  State<PathBreadcrumb> createState() => _PathBreadcrumbState();
}

class _PathBreadcrumbState extends State<PathBreadcrumb> {
  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    for (final (i, _) in this.widget.renderedPath.indexed) {
      widgets.add(Breadcrumb(
          path: GoalPath([
            ...this.widget.contextPath,
            ...this.widget.renderedPath.sublist(0, i + 1)
          ]),
          goalMap: this.widget.goalMap));
      widgets.add(const Icon(Icons.chevron_right));
    }
    if (widgets.isNotEmpty) widgets.removeLast();

    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

class ParentBreadcrumb extends StatefulWidget {
  final GoalPath path;
  final Map<String, Goal> goalMap;
  final VoidCallback? onRemove;
  const ParentBreadcrumb({
    super.key,
    required this.path,
    required this.goalMap,
    this.onRemove,
  });

  @override
  State<ParentBreadcrumb> createState() => _ParentBreadcrumbState();
}

class _ParentBreadcrumbState extends State<ParentBreadcrumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Goal? curGoal = this.widget.goalMap[this.widget.path.goalId];
    GoalPath parentPath = this.widget.path.parentPath;
    final path = <String>[];

    while (curGoal != null) {
      path.add(curGoal.id);

      if (isAnchor(curGoal) != null) {
        break;
      }
      curGoal = widget.goalMap[curGoal.superGoalIds.firstOrNull];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PathBreadcrumb(
            renderedPath: GoalPath(path.reversed.toList()),
            contextPath: parentPath,
            goalMap: this.widget.goalMap),
        if (this.widget.onRemove != null) ...[
          SizedBox(width: uiUnit(2)),
          Ink(
            decoration: ShapeDecoration(
              color: this._hovered ? palePinkColor : Colors.transparent,
              shape: CircleBorder(),
            ),
            child: SizedBox(
              width: 18.0,
              height: 18.0,
              child: IconButton(
                color: this._hovered ? deepRedColor : Colors.transparent,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16.0),
                onPressed: this.widget.onRemove,
              ),
            ),
          ),
        ]
      ]),
    );
  }
}
