import 'dart:math';

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
    final modalWidth = min(MediaQuery.of(context).size.width * .8, 600);
    return SizedBox(
      width: modalWidth.toDouble(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  suffixIcon: _textController.text.length > 0
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _textController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                focusNode: this._focusNode,
                controller: this._textController,
                onChanged: (_) => setState(() {})),
          ),
          SizedBox(
            height: 400,
            child: ListView(children: [
              for (final result in results)
                ListTile(
                  title: Text(result.text),
                  onTap: () {
                    Navigator.pop(context, result.id);
                  },
                ),
            ]),
          )
        ],
      ),
    );
  }
}
