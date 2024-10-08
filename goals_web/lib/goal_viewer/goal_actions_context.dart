import 'package:flutter/widgets.dart'
    show BuildContext, InheritedWidget, Widget;
import 'package:goals_core/model.dart';

import '../common/time_slice.dart';

class GoalDragDetails {
  final GoalPath path;

  const GoalDragDetails({
    required this.path,
  });
}

class GoalActionsContext extends InheritedWidget {
  final Function(List<String> goalId) onSelected;
  final Function(GoalPath) onFocused;
  final Function(List<String> goalId, {bool? expanded}) onExpanded;
  final Function(String? parentId, String text, [TimeSlice? slice]) onAddGoal;
  final Function(String?) onUnarchive;
  final Function(String?) onArchive;
  final Function(String?, DateTime?) onDone;
  final Function(String?, DateTime?) onSnooze;
  final Function(String) onMakeAnchor;
  final Function(String) onClearAnchor;
  final Function(String) onAddSummary;
  final Function(String) onClearSummary;
  final Function(
    GoalPath, {
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) onDropGoal;
  final Function(String?, {DateTime startTime, DateTime? endTime}) onActive;
  final Function(String? goalId)? onPrint;

  const GoalActionsContext({
    required Widget child,
    required this.onSelected,
    required this.onFocused,
    required this.onExpanded,
    required this.onAddGoal,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onSnooze,
    required this.onActive,
    required this.onDropGoal,
    required this.onMakeAnchor,
    required this.onClearAnchor,
    required this.onAddSummary,
    required this.onClearSummary,
    this.onPrint,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }

  static GoalActionsContext of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GoalActionsContext>()!;
  }

  // I don't LOVE this but it should work for now.
  // This feels like it should be represented with Intents and Actions.
  static GoalActionsContext overrideWith(
    BuildContext context, {
    required Widget child,
    Function(GoalPath)? onFocused,
    Function(String? parentId, String text, [TimeSlice? slice])? onAddGoal,
    Function(String?)? onUnarchive,
    Function(String?)? onArchive,
    Function(String?, DateTime?)? onDone,
    Function(String?, DateTime?)? onSnooze,
    Function(String?, {DateTime startTime, DateTime? endTime})? onActive,
    Function(
      GoalPath, {
      List<String>? dropPath,
      List<String>? prevDropPath,
      List<String>? nextDropPath,
    })? onDropGoal,
    Function(String? goalId)? onPrint,
    Function(String goalId)? onClearAnchor,
    Function(String goalId)? onMakeAnchor,
    Function(String goalId)? onAddSummary,
    Function(String goalId)? onClearSummary,
  }) {
    return GoalActionsContext(
      child: child,
      onSelected: GoalActionsContext.of(context).onSelected,
      onFocused: onFocused ?? GoalActionsContext.of(context).onFocused,
      onExpanded: GoalActionsContext.of(context).onExpanded,
      onAddGoal: onAddGoal ?? GoalActionsContext.of(context).onAddGoal,
      onUnarchive: onUnarchive ?? GoalActionsContext.of(context).onUnarchive,
      onArchive: onArchive ?? GoalActionsContext.of(context).onArchive,
      onDone: onDone ?? GoalActionsContext.of(context).onDone,
      onSnooze: onSnooze ?? GoalActionsContext.of(context).onSnooze,
      onActive: onActive ?? GoalActionsContext.of(context).onActive,
      onDropGoal: onDropGoal ?? GoalActionsContext.of(context).onDropGoal,
      onPrint: onPrint ?? GoalActionsContext.of(context).onPrint,
      onClearAnchor:
          onClearAnchor ?? GoalActionsContext.of(context).onClearAnchor,
      onMakeAnchor: onMakeAnchor ?? GoalActionsContext.of(context).onMakeAnchor,
      onAddSummary: onAddSummary ?? GoalActionsContext.of(context).onAddSummary,
      onClearSummary:
          onClearSummary ?? GoalActionsContext.of(context).onClearSummary,
    );
  }
}
