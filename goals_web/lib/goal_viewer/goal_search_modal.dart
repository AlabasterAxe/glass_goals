import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goals_core/model.dart' show Goal;

class GoalSearchModal extends StatefulWidget {
  final Map<String, Goal> goalMap;
  const GoalSearchModal({super.key, required this.goalMap});

  @override
  State<GoalSearchModal> createState() => _GoalSearchModalState();
}

class KeyboardFocusableListTile extends StatefulWidget {
  final Function onArrowUp;
  final Function onArrowDown;
  final Widget title;
  final bool isFocused;
  final Function()? onTap;
  const KeyboardFocusableListTile({
    super.key,
    required this.onArrowUp,
    required this.onArrowDown,
    required this.title,
    required this.isFocused,
    this.onTap,
  });

  @override
  State<KeyboardFocusableListTile> createState() =>
      _KeyboardFocusableListTileState();
}

class _KeyboardFocusableListTileState extends State<KeyboardFocusableListTile> {
  late final _focusNode = FocusNode(onKey: (node, event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      this.widget.onArrowUp();
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      this.widget.onArrowDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  @override
  void didUpdateWidget(covariant KeyboardFocusableListTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFocused != widget.isFocused) {
      if (widget.isFocused) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      focusNode: _focusNode,
      title: widget.title,
      onTap: widget.onTap,
    );
  }
}

class _GoalSearchModalState extends State<GoalSearchModal> {
  final _textController = TextEditingController();
  late final FocusNode _textFocusNode = FocusNode(onKey: (node, event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      setState(() {
        _textFocusNode.unfocus();
        _selectedIndex = 0;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  int? _selectedIndex = null;

  @override
  void initState() {
    super.initState();

    _textFocusNode.requestFocus();
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
                focusNode: this._textFocusNode,
                controller: this._textController,
                onChanged: (_) => setState(() {})),
          ),
          SizedBox(
            height: 400,
            child: ListView(primary: true, children: [
              for (final (i, result) in results.indexed)
                KeyboardFocusableListTile(
                    isFocused: _selectedIndex == i,
                    title: Text(result.text),
                    onTap: () {
                      Navigator.pop(context, result.id);
                    },
                    onArrowUp: () {
                      if (i == 0) {
                        _textFocusNode.requestFocus();
                        _selectedIndex = null;
                      } else {
                        setState(() {
                          _selectedIndex = i - 1;
                        });
                      }
                    },
                    onArrowDown: () {
                      if (i == results.length - 1) {
                        _textFocusNode.requestFocus();
                      } else {
                        setState(() {
                          _selectedIndex = i + 1;
                        });
                      }
                    }),
            ]),
          )
        ],
      ),
    );
  }
}
