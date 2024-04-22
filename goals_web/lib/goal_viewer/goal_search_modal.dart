import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_web/goal_viewer/status_chip.dart';

import '../styles.dart';

class GoalSearchModal extends StatefulWidget {
  final Map<String, Goal> goalMap;
  const GoalSearchModal({super.key, required this.goalMap});

  @override
  State<GoalSearchModal> createState() => _GoalSearchModalState();
}

class KeyboardFocusableListTile extends StatefulWidget {
  final Goal goal;
  final bool isFocused;
  final Function()? onTap;
  const KeyboardFocusableListTile({
    super.key,
    required this.goal,
    required this.isFocused,
    this.onTap,
  });

  @override
  State<KeyboardFocusableListTile> createState() =>
      _KeyboardFocusableListTileState();
}

class _KeyboardFocusableListTileState extends State<KeyboardFocusableListTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: this.widget.isFocused ? Colors.grey.withOpacity(.1) : null,
      child: ListTile(
        selected: this.widget.isFocused,
        title: Row(
          children: [
            Text(this.widget.goal.text),
            SizedBox(width: uiUnit()),
            CurrentStatusChip(goal: this.widget.goal),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

class _GoalSearchModalState extends State<GoalSearchModal> {
  final _textController = TextEditingController();
  late final FocusNode _textFocusNode = FocusNode(onKey: (node, event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      setState(() {
        this._selectedIndex++;
      });
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      setState(() {
        this._selectedIndex--;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  String _lastText = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    this._textFocusNode.requestFocus();
    this._textController.addListener(() {
      if (this._textController.text != this._lastText) {
        setState(() {
          this._selectedIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
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
    final wrappedSelectedIndex = this._selectedIndex % results.length;
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
                onSubmitted: (_) {
                  Navigator.pop(context, results[wrappedSelectedIndex].id);
                },
                focusNode: this._textFocusNode,
                controller: this._textController,
                onChanged: (_) => setState(() {})),
          ),
          SizedBox(
            height: 400,
            child: ListView(primary: true, children: [
              for (final (i, goal) in results.indexed)
                KeyboardFocusableListTile(
                  isFocused: wrappedSelectedIndex == i,
                  onTap: () {
                    Navigator.pop(context, goal.id);
                  },
                  goal: goal,
                ),
            ]),
          )
        ],
      ),
    );
  }
}
