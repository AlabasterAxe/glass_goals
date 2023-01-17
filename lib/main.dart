import 'package:flutter/material.dart';

import 'model.dart';

void main() {
  runApp(const MyApp());
}

final ROOT_GOAL = Goal(text: 'To live a fulfilling life', subGoals: [
  Goal(text: 'Succeed Professionally'),
  Goal(text: 'Create things'),
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
      body: PageView(
        children: [
          Center(
            child: Text('Hello World', style: TextStyle(color: Colors.white)),
          ),
          Center(
            child: Text('Hello 1', style: TextStyle(color: Colors.white)),
          ),
          Center(
            child: Text('Hello 2', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
