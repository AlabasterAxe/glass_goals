import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_goals/styles.dart';

import 'app_context.dart' show AppContext;
import 'glass_scaffold.dart';
import 'goal.dart' show GoalWidget, GoalTitle;
import 'model.dart' show Goal;
import 'stt_service.dart' show SttService;

void main() {
  runApp(const GlassGoals());
}

final rootGoal = Goal(id: '0', text: 'Live a fulfilling life', subGoals: [
  Goal(id: '1', text: 'Succeed Professionally'),
  Goal(id: '2', text: 'Create things'),
]);

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key});

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals> {
  double x = 0;
  double y = 0;
  SttService sttService = SttService();

  @override
  Widget build(BuildContext context) {
    return AppContext(
        sttService: sttService,
        child: MaterialApp(
          title: 'Glass Goals',
          theme: ThemeData(
            primaryColor: Colors.black,
            textTheme: const TextTheme(
              bodyText1: TextStyle(color: Colors.white),
              bodyText2: TextStyle(color: Colors.white),
              headline1: mainTextStyle,
            ),
          ),
          home: GoalsHome(),
        ));
  }
}

class GoalsHome extends StatelessWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 20) {
              SystemNavigator.pop();
            }
          },
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        GlassScaffold(child: GoalWidget(rootGoal))));
          },
          child: Center(
              child: Hero(
                  tag: rootGoal.id,
                  child: GoalTitle(rootGoal, key: ValueKey(rootGoal.id))))),
    );
  }
}
