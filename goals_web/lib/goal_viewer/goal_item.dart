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
import 'package:flutter/src/widgets/async.dart';
import 'package:flutter/src/widgets/basic.dart';
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
        Text,
        TextEditingController,
        Widget,
        pointerDragAnchorStrategy;
import 'package:goals_core/model.dart'
    show Goal, GoalPath, hasParentContext, hasSummary;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/goal_note.dart';
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
        DragEventType,
        dragEventProvider,
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
  final GoalPath path;
  final EdgeInsetsGeometry padding;
  final bool pendingShiftSelect;
  final Map<String, Goal> goalMap;

  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.hoverActionsBuilder,
    required this.hasRenderableChildren,
    this.showExpansionArrow = true,
    this.dragHandle = GoalItemDragHandle.none,
    this.onDropGoal,
    this.path = const GoalPath([]),
    this.padding = const EdgeInsets.all(0),
    this.pendingShiftSelect = false,
    required this.goalMap,
  });

  @override
  ConsumerState<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends ConsumerState<GoalItemWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // TODO: maybe this should be a state machine?
  bool _editing = false;
  bool _hovering = false;
  bool _dragging = false;

  List<StreamSubscription> subscriptions = [];

  @override
  void initState() {
    super.initState();

    subscriptions.add(hoverEventStream.listen((hoveredPath) {
      if (!pathsMatch(hoveredPath, widget.path) && _hovering) {
        setState(() {
          _hovering = false;
        });
      } else if (pathsMatch(hoveredPath, widget.path) && !_hovering) {
        setState(() {
          _hovering = true;
        });
      }

      if (pathsMatch(hoveredPath, this.widget.path) &&
          textFocusStream.value == null &&
          dragEventProvider.value != DragEventType.start) {
        this._focusNode.requestFocus();
      }
    }));

    this._focusNode.addListener(() {
      if (!this._focusNode.hasPrimaryFocus) {
        setState(() {});
      }
    });
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

  @override
  didUpdateWidget(GoalItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingShiftSelect != widget.pendingShiftSelect) {
      setState(() {});
    }
  }

  _updateGoal() {
    AppContext.of(context)
        .syncClient
        .modifyGoal(GoalDelta(id: widget.goal.id, text: _textController.text));
    setState(() {
      _editing = false;
    });
  }

  Widget _dragWrapWidget({
    required Widget child,
    required bool isSelected,
    required List<List<String>> selectedGoals,
  }) {
    return Draggable<GoalDragDetails>(
      data: GoalDragDetails(path: this.widget.path),
      hitTestBehavior: HitTestBehavior.opaque,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        this._focusNode.requestFocus();
        if (dragEventProvider.value == DragEventType.start) {
          dragEventProvider.add(DragEventType.cancel);
        }
        dragEventProvider.add(DragEventType.start);
        setState(() {
          this._dragging = true;
        });
      },
      onDragCompleted: () {
        if (dragEventProvider.value == DragEventType.start) {
          dragEventProvider.add(DragEventType.end);
        }
        setState(() {
          this._dragging = false;
        });
      },
      onDraggableCanceled: (_, __) {
        if (dragEventProvider.value == DragEventType.start) {
          dragEventProvider.add(DragEventType.cancel);
        }
        setState(() {
          this._dragging = false;
        });
      },
      feedback: StreamBuilder(
          stream: dragEventProvider.stream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == DragEventType.cancel) {
              return Container();
            }
            return Container(
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text((isSelected ? selectedGoals.length : 1).toString(),
                    style: const TextStyle(
                        fontSize: 20,
                        decoration: TextDecoration.none,
                        color: Colors.white)),
              ),
            );
          }),
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

    final isSelected = selectedGoals.contains(widget.path);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final onExpanded = GoalActionsContext.of(context).onExpanded;
    final onFocused = GoalActionsContext.of(context).onFocused;
    final onSelected = GoalActionsContext.of(context).onSelected;
    final summary = hasSummary(widget.goal);
    final parentComment = widget.path.parentId != null
        ? hasParentContext(widget.goal, widget.path.parentId!)
        : null;
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
                onSelected.call(widget.path);
                onFocused.call(GoalPath(widget.path));
              },
        child: Container(
          decoration: BoxDecoration(
            color: _hovering || widget.pendingShiftSelect
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
                            selectedGoals: selectedGoals,
                          )
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
                                  onLongPress: !hasMouse ? _startEditing : null,
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
                if (!isNarrow && !_editing && (isSelected || _hovering))
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: widget
                        .hoverActionsBuilder(GoalPath([...this.widget.path])),
                  )
              ],
            ),
          ),
        ),
      ),
    );
    return Actions(
      actions: {
        if (this._editing)
          CancelIntent: CallbackAction<CancelIntent>(
            onInvoke: (_) {
              this._cancelEditing();
            },
          ),
        if (this._dragging)
          CancelIntent: CallbackAction<CancelIntent>(
            onInvoke: (_) {
              dragEventProvider.add(DragEventType.cancel);
              setState(() {
                this._dragging = false;
              });
            },
          ),
        if (this._editing)
          AcceptIntent: CallbackAction<AcceptIntent>(
            onInvoke: (_) {
              this._updateGoal();
            },
          ),
        AcceptMultiLineTextIntent: CallbackAction<AcceptMultiLineTextIntent>(
          onInvoke: (_) {
            this._updateGoal();
          },
        ),
        if (!this._editing && this._focusNode.hasPrimaryFocus)
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (ActivateIntent intent) {
            onFocused.call(GoalPath(widget.path));
          })
      },
      child: DragTarget<GoalDragDetails>(
        onAcceptWithDetails: (details) {
          if (dragEventProvider.value == DragEventType.start) {
            this.widget.onDropGoal?.call(details.data);
          }
        },
        onMove: (details) {
          if (!_hovering) {
            hoverEventStream.add(this.widget.path);
            setState(() {
              _hovering = true;
            });
          }
        },
        builder: (context, _, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.dragHandle == GoalItemDragHandle.item
                ? _dragWrapWidget(
                    isSelected: isSelected,
                    selectedGoals: selectedGoals,
                    child: content,
                  )
                : content,
            if (summary != null && isExpanded)
              Container(
                color: hoverEventStream.value == widget.path
                    ? emphasizedLightBackground
                    : Colors.transparent,
                padding: EdgeInsets.only(
                    left: uiUnit(10) + widget.padding.horizontal),
                child: NoteCard(
                  smallText: true,
                  goalMap: widget.goalMap,
                  textEntry: summary,
                  isChildGoal: false,
                  path: widget.path,
                  onRefresh: () {},
                ),
              ),
            if (parentComment != null && isExpanded)
              Container(
                color: hoverEventStream.value == widget.path
                    ? emphasizedLightBackground
                    : Colors.transparent,
                padding: EdgeInsets.only(
                    left: uiUnit(10) + widget.padding.horizontal),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      vertical: uiUnit(1), horizontal: uiUnit(2)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border(
                      left: BorderSide(
                        width: 2,
                        color: darkElementColor,
                      ),
                    ),
                    color: palerBlueColor,
                  ),
                  child: NoteCard(
                    smallText: true,
                    goalMap: widget.goalMap,
                    textEntry: parentComment,
                    isChildGoal: false,
                    path: widget.path,
                    onRefresh: () {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
