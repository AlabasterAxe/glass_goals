import 'package:flutter/painting.dart' show TextDecoration, TextStyle;
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart'
    show BuildContext, GestureDetector, MouseRegion, Text, Widget;
import 'package:goals_core/model.dart' show Goal, GoalPath;
import 'package:goals_web/goal_viewer/goal_actions_context.dart';
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
