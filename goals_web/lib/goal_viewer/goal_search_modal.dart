import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal;

import '../app_context.dart';

class GoalSearchModal extends StatefulWidget {
  final Map<String, Goal> goalMap;
  const GoalSearchModal({super.key, required this.goalMap});

  @override
  State<GoalSearchModal> createState() => _GoalSearchModalState();
}

class _GoalSearchModalState extends State<GoalSearchModal> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final results = this
        .widget
        .goalMap
        .values
        .where((goal) => goal.text
            .toLowerCase()
            .contains(_textController.text.toLowerCase()))
        .toList();
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: this._textController,
          ),
          for (final result in results) Text(result.text),
        ],
      ),
    );
  }
}
