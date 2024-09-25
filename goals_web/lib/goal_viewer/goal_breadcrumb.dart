import 'package:flutter/painting.dart' show TextDecoration, TextStyle;
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart'
    show BuildContext, GestureDetector, MouseRegion, Text, Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_web/goal_viewer/providers.dart' show focusedGoalStream;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

class Breadcrumb extends ConsumerWidget {
  final Goal goal;
  const Breadcrumb({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          child: Text(goal.text,
              style: TextStyle(decoration: TextDecoration.underline)),
          onTap: () {
            focusedGoalStream.add(goal.id);
          }),
    );
  }
}
