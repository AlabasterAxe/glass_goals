import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal;

class GoalSearchModal extends StatefulWidget {
  final Map<String, Goal> goalMap;
  const GoalSearchModal({super.key, required this.goalMap});

  @override
  State<GoalSearchModal> createState() => _GoalSearchModalState();
}

class _GoalSearchModalState extends State<GoalSearchModal> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final results = _textController.text.length == 0
        ? []
        : this
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
              focusNode: this._focusNode,
              controller: this._textController,
              onChanged: (_) => setState(() {})),
          for (final result in results) Text(result.text),
        ],
      ),
    );
  }
}
