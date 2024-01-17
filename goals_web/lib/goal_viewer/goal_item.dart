import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app_context.dart';
import '../styles.dart';
import 'goal_actions_context.dart';
import 'providers.dart'
    show
        expandedGoalsProvider,
        focusedGoalProvider,
        hoverEventStream,
        pathsMatch,
        selectedGoalsProvider;

enum GoalItemDragHandle {
  none,
  bullet,
  item,
}

class GoalItemWidget extends StatefulHookConsumerWidget {
  final Goal goal;

  final HoverActionsBuilder hoverActionsBuilder;
  final bool hasRenderableChildren;
  final bool showExpansionArrow;
  final GoalItemDragHandle dragHandle;
  final Function(String goalId)? onDropGoal;
  final List<String> path;

  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.hoverActionsBuilder,
    required this.hasRenderableChildren,
    this.showExpansionArrow = true,
    this.dragHandle = GoalItemDragHandle.none,
    this.onDropGoal,
    this.path = const [],
  });

  @override
  ConsumerState<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends ConsumerState<GoalItemWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _editing = false;
  final FocusNode _focusNode = FocusNode();
  bool _hovering = false;

  List<StreamSubscription> subscriptions = [];

  @override
  void initState() {
    super.initState();

    subscriptions.add(hoverEventStream.listen((id) {
      if (id != widget.goal.id) {
        setState(() {
          _hovering = false;
        });
      }
    }));
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.goal.text != _textController.text) {
      _textController.text = widget.goal.text;
    }
  }

  @override
  void dispose() {
    for (final subscription in this.subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  Widget _dragWrapWidget(
      {required Widget child,
      required bool isSelected,
      required Set<String> selectedGoals}) {
    return Draggable<String>(
      data: widget.goal.id,
      hitTestBehavior: HitTestBehavior.opaque,
      feedback: Container(
        decoration:
            const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text((isSelected ? selectedGoals.length : 1).toString(),
              style: const TextStyle(
                  fontSize: 20,
                  decoration: TextDecoration.none,
                  color: Colors.white)),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded =
        ref.watch(expandedGoalsProvider).contains(widget.goal.id);
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final isFocused = ref.watch(focusedGoalProvider) == widget.goal.id;
    final isSelected = selectedGoals.contains(widget.goal.id);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final onExpanded = GoalActionsContext.of(context).onExpanded;
    final onFocused = GoalActionsContext.of(context).onFocused;
    final bullet = SizedBox(
      width: uiUnit(10),
      height: uiUnit(8),
      child: Center(
          child: Container(
        width: uiUnit(),
        height: uiUnit(),
        decoration: BoxDecoration(
          color: darkElementColor,
          borderRadius: BorderRadius.circular(uiUnit()),
        ),
      )),
    );
    final content = MouseRegion(
      onHover: (event) {
        setState(() {
          if (!_hovering) {
            _hovering = true;
            hoverEventStream.add(this.widget.path);
          }
        });
      },
      child: GestureDetector(
        onTap: _editing
            ? null
            : () {
                onFocused?.call(widget.goal.id);
              },
        child: StreamBuilder<List<String>?>(
            stream: hoverEventStream.stream,
            builder: (context, snapshot) {
              return Container(
                decoration: BoxDecoration(
                  color: (_hovering ||
                          snapshot.hasData &&
                              pathsMatch(
                                  snapshot.requireData, this.widget.path))
                      ? emphasizedLightBackground
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        widget.dragHandle == GoalItemDragHandle.bullet
                            ? _dragWrapWidget(
                                child: bullet,
                                isSelected: isSelected,
                                selectedGoals: selectedGoals)
                            : bullet,
                        _editing
                            ? IntrinsicWidth(
                                child: TextField(
                                  autocorrect: false,
                                  controller: _textController,
                                  decoration: null,
                                  style: mainTextStyle,
                                  onEditingComplete: () {
                                    AppContext.of(context)
                                        .syncClient
                                        .modifyGoal(GoalDelta(
                                            id: widget.goal.id,
                                            text: _textController.text));
                                    setState(() {
                                      _editing = false;
                                    });
                                  },
                                  onTapOutside: (_) {
                                    setState(() {
                                      _editing = false;
                                      _focusNode.unfocus();
                                    });
                                  },
                                  focusNode: _focusNode,
                                ),
                              )
                            : Flexible(
                                child: GestureDetector(
                                  onDoubleTap: _editing || !isSelected
                                      ? null
                                      : () => {
                                            setState(() {
                                              _editing = true;
                                              _focusNode.requestFocus();
                                            })
                                          },
                                  child: Text(widget.goal.text,
                                      style: (isFocused
                                              ? focusedFontStyle
                                                  .merge(mainTextStyle)
                                              : mainTextStyle)
                                          .copyWith(
                                        decoration: isSelected
                                            ? TextDecoration.underline
                                            : null,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                ),
                              ),
                        SizedBox(width: uiUnit(2)),
                        // chip-like container widget around text status widget:
                        StatusChip(goal: widget.goal),
                        if (this.widget.showExpansionArrow)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => onExpanded(widget.goal.id),
                                icon: Icon(
                                    size: 24,
                                    isExpanded
                                        ? Icons.arrow_drop_down
                                        : widget.hasRenderableChildren
                                            ? Icons.arrow_right
                                            : Icons.add)),
                          ),
                      ]),
                    ),
                    if (!isNarrow &&
                        !_editing &&
                        (isSelected ||
                            _hovering ||
                            snapshot.hasData &&
                                pathsMatch(
                                    snapshot.requireData, this.widget.path)))
                      widget.hoverActionsBuilder(widget.goal.id)
                  ],
                ),
              );
            }),
      ),
    );
    return DragTarget<String>(
      onAccept: this.widget.onDropGoal,
      onMove: (details) {
        setState(() {
          if (!_hovering) {
            _hovering = true;
            hoverEventStream.add(this.widget.path);
          }
        });
      },
      builder: (context, _, __) => widget.dragHandle == GoalItemDragHandle.item
          ? _dragWrapWidget(
              isSelected: isSelected,
              selectedGoals: selectedGoals,
              child: content,
            )
          : content,
    );
  }
}
