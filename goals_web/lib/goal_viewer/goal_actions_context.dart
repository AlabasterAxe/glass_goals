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
  final Function(GoalPath) onMakeAnchor;
  final Function(GoalPath) onClearAnchor;
  final Function(GoalPath) onAddSummary;
  final Function(GoalPath) onClearSummary;
  final Function(GoalPath) onAddContextComment;
  final Function(GoalPath) onClearContextComment;
  final Function(
    GoalPath, {
    List<String>? dropPath,
    List<String>? prevDropPath,
    List<String>? nextDropPath,
  }) onDropGoal;
  final Function(String?, {DateTime startTime, DateTime? endTime}) onActive;
  final Function(GoalPath goalId)? onPrint;

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
    required this.onAddContextComment,
    required this.onClearContextComment,
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
    Function(GoalPath)? onPrint,
    Function(GoalPath)? onClearAnchor,
    Function(GoalPath)? onMakeAnchor,
    Function(GoalPath)? onAddSummary,
    Function(GoalPath)? onClearSummary,
    Function(GoalPath)? onAddContextComment,
    Function(GoalPath)? onClearContextComment,
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
      onAddContextComment: onAddContextComment ??
          GoalActionsContext.of(context).onAddContextComment,
      onClearContextComment: onClearContextComment ??
          GoalActionsContext.of(context).onClearContextComment,
    );
  }
}
