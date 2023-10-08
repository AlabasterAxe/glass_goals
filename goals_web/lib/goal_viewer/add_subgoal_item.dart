import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:goals_core/sync.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../app_context.dart';
import '../styles.dart';

class AddSubgoalItemWidget extends StatefulWidget {
  final String? parentId;
  final Function()? onEnter;
  final Function()? onDismiss;
  final Function()? onTab;
  const AddSubgoalItemWidget({
    super.key,
    this.parentId,
    this.onEnter,
    this.onDismiss,
    this.onTab,
  });

  @override
  State<AddSubgoalItemWidget> createState() => _AddSubgoalItemWidgetState();
}

class _AddSubgoalItemWidgetState extends State<AddSubgoalItemWidget> {
  TextEditingController? _textController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _focusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_textController == null) {
      _textController = TextEditingController(text: "");
    } else {
      _textController!.text = "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.escape): () {
          widget.onDismiss?.call();
        },
        LogicalKeySet(LogicalKeyboardKey.tab): () {
          widget.onTab?.call();
        },
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            SizedBox(
              width: uiUnit(10),
              height: uiUnit(10),
              child: const Center(child: Icon(Icons.add, size: 18)),
            ),
            IntrinsicWidth(
              child: TextField(
                autocorrect: false,
                controller: _textController,
                decoration: null,
                style: mainTextStyle,
                onEditingComplete: () {
                  final newText = _textController!.text;
                  _textController!.text = "";
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: const Uuid().v4(),
                      text: newText,
                      parentId: widget.parentId));
                  widget.onEnter?.call();
                },
                onTapOutside: (_) {
                  widget.onDismiss?.call();
                },
                focusNode: _focusNode,
              ),
            )
          ],
        ),
      ),
    );
  }
}
