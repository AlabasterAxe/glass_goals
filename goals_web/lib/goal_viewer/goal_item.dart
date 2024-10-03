import 'dart:async';

import 'package:flutter/material.dart'
    show Colors, IconButton, Icons, TextField;
import 'package:flutter/painting.dart'
    show
        BorderRadius,
        BoxDecoration,
        BoxShape,
        EdgeInsets,
        EdgeInsetsGeometry,
        TextDecoration,
        TextOverflow,
        TextStyle;
import 'package:flutter/rendering.dart'
    show HitTestBehavior, MainAxisAlignment, MainAxisSize;
import 'package:flutter/services.dart' show SystemMouseCursors, TextSelection;
import 'package:flutter/widgets.dart'
    show
        Actions,
        BuildContext,
        CallbackAction,
        Center,
        Container,
        DragTarget,
        Draggable,
        Flexible,
        Focus,
        FocusNode,
        GestureDetector,
        Icon,
        IntrinsicWidth,
        MediaQuery,
        MouseRegion,
        Padding,
        Row,
        SizedBox,
        StreamBuilder,
        Text,
        TextEditingController,
        Widget,
        pointerDragAnchorStrategy;
import 'package:goals_core/model.dart' show Goal, GoalPath;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:goals_web/goal_viewer/status_chip.dart';
import 'package:goals_web/intents.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app_context.dart';
import '../styles.dart';
import 'goal_actions_context.dart';
import 'providers.dart'
    show
        expandedGoalsProvider,
        expandedGoalsStream,
        hasMouseProvider,
        hoverEventStream,
        pathsMatch,
        selectedGoalsProvider,
        selectedGoalsStream,
        textFocusStream;

import 'package:collection/collection.dart' show IterableExtension;

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
  final Function(GoalDragDetails goalId)? onDropGoal;
  final List<String> path;
  final EdgeInsetsGeometry padding;

  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.hoverActionsBuilder,
    required this.hasRenderableChildren,
    this.showExpansionArrow = true,
    this.dragHandle = GoalItemDragHandle.none,
    this.onDropGoal,
    this.path = const [],
    this.padding = const EdgeInsets.all(0),
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
      if (id?.lastOrNull != widget.goal.id) {
        setState(() {
          _hovering = false;
        });
      }

      if (pathsMatch(id, this.widget.path) && textFocusStream.value == null) {
        this._focusNode.requestFocus();
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

  _cancelEditing() {
    hoverEventStream.add(null);
    this._focusNode.unfocus();
    this._textController.text = widget.goal.text;
    this.setState(() {
      this._editing = false;
    });
  }

  _updateGoal() {
    AppContext.of(context)
        .syncClient
        .modifyGoal(GoalDelta(id: widget.goal.id, text: _textController.text));
    setState(() {
      _editing = false;
    });
  }

  Widget _dragWrapWidget(
      {required Widget child,
      required bool isSelected,
      required List<List<String>> selectedGoals}) {
    return Draggable<GoalDragDetails>(
      data:
          GoalDragDetails(goalId: widget.goal.id, sourcePath: this.widget.path),
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

  _startEditing() {
    this._textController.text = widget.goal.text;
    this._focusNode.requestFocus();
    this._textController.selection =
        TextSelection(baseOffset: 0, extentOffset: _textController.text.length);
    textFocusStream.add([...this.widget.path]);
    setState(() {
      _editing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expandedGoals =
        ref.watch(expandedGoalsProvider).value ?? expandedGoalsStream.value;
    final isExpanded = expandedGoals
            .firstWhereOrNull((p) => pathsMatch(p, this.widget.path)) !=
        null;
    final selectedGoals =
        ref.watch(selectedGoalsProvider).value ?? selectedGoalsStream.value;
    final hasMouse = ref.watch(hasMouseProvider);

    final isSelected = selectedGoals.contains(widget.goal.id);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final onExpanded = GoalActionsContext.of(context).onExpanded;
    final onFocused = GoalActionsContext.of(context).onFocused;
    final onSelected = GoalActionsContext.of(context).onSelected;
    final bullet = SizedBox(
      width: uiUnit(10),
      height: uiUnit(hasMouse ? 8 : 12),
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
        if (!_hovering) {
          hoverEventStream.add(this.widget.path);
          setState(() {
            _hovering = true;
          });
        }
      },
      child: GestureDetector(
        onTap: _editing
            ? null
            : () {
                setState(() {
                  onSelected.call(widget.path);
                  onFocused.call(GoalPath(widget.path));
                });
              },
        child: StreamBuilder<List<String>?>(
            stream: hoverEventStream.stream,
            builder: (context, hoveredGoalSnapshot) {
              return Container(
                decoration: BoxDecoration(
                  color: (_hovering ||
                          hoveredGoalSnapshot.hasData &&
                              pathsMatch(hoveredGoalSnapshot.requireData,
                                  this.widget.path))
                      ? emphasizedLightBackground
                      : Colors.transparent,
                ),
                child: Padding(
                  padding: widget.padding,
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

                                    // NOTE: this is a workaround so that the text field doesn't
                                    // auto-highlight when switching between windows.
                                    maxLines: null,
                                    style: mainTextStyle,
                                    onEditingComplete: this._updateGoal,
                                    onTapOutside: (_) {
                                      _updateGoal();
                                    },
                                    focusNode: _focusNode,
                                  ),
                                )
                              : Flexible(
                                  child: Focus(
                                    focusNode: _focusNode,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.text,
                                      child: GestureDetector(
                                        onTap: hasMouse ? _startEditing : null,
                                        onLongPress:
                                            !hasMouse ? _startEditing : null,
                                        child: Text(widget.goal.text,
                                            style: (isSelected
                                                    ? focusedFontStyle
                                                        .merge(mainTextStyle)
                                                    : mainTextStyle)
                                                .copyWith(
                                              decoration:
                                                  TextDecoration.underline,
                                              overflow: TextOverflow.ellipsis,
                                            )),
                                      ),
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
                                  onPressed: () => onExpanded(widget.path),
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
                              hoveredGoalSnapshot.hasData &&
                                  pathsMatch(hoveredGoalSnapshot.requireData,
                                      this.widget.path)))
                        widget.hoverActionsBuilder([...this.widget.path])
                    ],
                  ),
                ),
              );
            }),
      ),
    );
    return Actions(
      actions: {
        CancelIntent: CallbackAction<CancelIntent>(
          onInvoke: (_) {
            this._cancelEditing();
          },
        ),
        AcceptIntent: CallbackAction<AcceptIntent>(
          onInvoke: (_) {
            this._updateGoal();
          },
        ),
        if (!this._editing)
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (ActivateIntent intent) {
            onFocused.call(GoalPath(widget.path));
          })
      },
      child: DragTarget<GoalDragDetails>(
        onAcceptWithDetails: (deets) =>
            this.widget.onDropGoal?.call(deets.data),
        onMove: (details) {
          if (!_hovering) {
            hoverEventStream.add(this.widget.path);
            setState(() {
              _hovering = true;
            });
          }
        },
        builder: (context, _, __) =>
            widget.dragHandle == GoalItemDragHandle.item
                ? _dragWrapWidget(
                    isSelected: isSelected,
                    selectedGoals: selectedGoals,
                    child: content,
                  )
                : content,
      ),
    );
  }
}
