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
  final TextStyle? style;
  const Breadcrumb({
    super.key,
    required this.goal,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          child: Text(goal.text,
              style: this.style != null
                  ? this.style!.copyWith(decoration: TextDecoration.underline)
                  : TextStyle(decoration: TextDecoration.underline)),
          onTap: () {
            focusedGoalStream.add(goal.id);
          }),
    );
  }
}
