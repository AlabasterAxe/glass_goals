import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Navigator,
        PageController,
        State,
        StatefulWidget,
        ValueKey,
        Widget;
import 'package:goals_core/model.dart' show Goal;

import '../util/glass_page_view.dart';
import 'goal_card.dart';

class GoalList extends StatefulWidget {
  final Map<String, Goal> goalState;

  const GoalList(this.goalState, {super.key});

  @override
  State<GoalList> createState() => _GoalListState();
}

class _GoalListState extends State<GoalList> {
  late PageController _pageController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageController = PageController();
  }

  onBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPageView(
      controller: _pageController,
      children: [
        ...widget.goalState.values
            .map((subGoal) => GoalCard(
                key: ValueKey(subGoal.id), goal: subGoal, onBack: onBack))
            .toList(),
      ],
    );
  }
}
