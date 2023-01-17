import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_scaffold.dart';
import 'goal.dart';
import 'model.dart';
import 'styles.dart';

void main() {
  runApp(const MyApp());
}

final rootGoal = Goal(id: '0', text: 'Live a fulfilling life', subGoals: [
  Goal(id: '1', text: 'Succeed Professionally'),
  Goal(id: '2', text: 'Create things'),
]);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glass Goals',
      theme: ThemeData(
        primaryColor: Colors.black,
        textTheme: const TextTheme(
          bodyText1: TextStyle(color: Colors.white),
          bodyText2: TextStyle(color: Colors.white),
        ),
      ),
      home: const GlassGoals(title: 'Glass Goals'),
    );
  }
}

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key, required this.title});

  final String title;

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals> {
  double x = 0;
  double y = 0;

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
          child: Center(child: Text(rootGoal.text, style: mainTextStyle))),
    );
  }
}
