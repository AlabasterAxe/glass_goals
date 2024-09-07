import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        expandedGoalsStream,
        hoverEventStream,
        pathsMatch,
        selectedGoalsProvider,
        selectedGoalsStream;

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
  late final FocusNode _focusNode = FocusNode(onKeyEvent: (node, event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      hoverEventStream.add(null);
      this._focusNode.unfocus();
      this._textController.text = widget.goal.text;
      this.setState(() {
        this._editing = false;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });
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
      dragAnchorStrategy: pointerDragAnchorStrategy,
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
    final expandedGoals =
        ref.watch(expandedGoalsProvider).value ?? expandedGoalsStream.value;
    final isExpanded = expandedGoals.contains(widget.goal.id);
    final selectedGoals =
        ref.watch(selectedGoalsProvider).value ?? selectedGoalsStream.value;

    final isSelected = selectedGoals.contains(widget.goal.id);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final onExpanded = GoalActionsContext.of(context).onExpanded;
    final onFocused = GoalActionsContext.of(context).onFocused;
    final onSelected = GoalActionsContext.of(context).onSelected;
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
      cursor: SystemMouseCursors.click,
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
                setState(() {
                  onSelected.call(widget.goal.id);
                  onFocused.call(widget.goal.id);
                });
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
                                    AppContext.of(context)
                                        .syncClient
                                        .modifyGoal(GoalDelta(
                                            id: widget.goal.id,
                                            text: _textController.text));
                                    setState(() {
                                      _editing = false;
                                    });
                                  },
                                  focusNode: _focusNode,
                                ),
                              )
                            : Flexible(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.text,
                                  child: GestureDetector(
                                    onTap: () {
                                      this._textController.text =
                                          widget.goal.text;
                                      _focusNode.requestFocus();
                                      setState(() {
                                        _editing = true;
                                      });
                                    },
                                    child: Text(widget.goal.text,
                                        style: (isSelected
                                                ? focusedFontStyle
                                                    .merge(mainTextStyle)
                                                : mainTextStyle)
                                            .copyWith(
                                          decoration: TextDecoration.underline,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                  ),
                                ),
                              ),
                        SizedBox(width: uiUnit(2)),
                        // chip-like container widget around text status widget:
                        CurrentStatusChip(goal: widget.goal),
                        if (this.widget.showExpansionArrow &&
                            widget.hasRenderableChildren)
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
                                        : Icons.arrow_right)),
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
                      widget.hoverActionsBuilder([...this.widget.path])
                  ],
                ),
              );
            }),
      ),
    );
    return DragTarget<String>(
      onAcceptWithDetails: (deets) => this.widget.onDropGoal?.call(deets.data),
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
