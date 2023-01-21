import 'dart:developer' show log;

import 'package:flutter/material.dart'
    show CircularProgressIndicator, Colors, Theme;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Container,
        GestureDetector,
        Hero,
        HitTestBehavior,
        PageView,
        Positioned,
        SizedBox,
        Stack,
        State,
        StatefulWidget,
        StatelessWidget,
        StreamBuilder,
        Text,
        TextStyle,
        ValueKey,
        Widget;
import 'package:uuid/uuid.dart' show Uuid;

import 'app_context.dart' show AppContext;
import 'model.dart' show Goal;
import 'stt_service.dart' show SttState;
import 'styles.dart' show mainTextStyle;

class GoalTitle extends StatelessWidget {
  final Goal goal;

  const GoalTitle(this.goal, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        goal.text,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }
}

class AddSubGoalCard extends StatefulWidget {
  final Function(String) onGoalText;
  final Function(Object) onError;
  const AddSubGoalCard(
      {super.key, required this.onGoalText, required this.onError});

  @override
  State<AddSubGoalCard> createState() => _AddSubGoalCardState();
}

class _AddSubGoalCardState extends State<AddSubGoalCard> {
  @override
  Widget build(BuildContext context) {
    final stt = AppContext.of(context).sttService;

    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            widget.onGoalText(await stt.detectSpeech());
          } catch (e) {
            widget.onError(e);
          }
        },
        child: Center(
            child: Text('+',
                style: mainTextStyle.merge(const TextStyle(fontSize: 100)))));
  }
}

class GoalWidget extends StatefulWidget {
  final Goal goal;

  const GoalWidget(this.goal, {super.key});

  @override
  State<GoalWidget> createState() => _GoalWidgetState();
}

class _GoalWidgetState extends State<GoalWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Center(
                child: Hero(
              tag: widget.goal.id,
              child: GoalTitle(widget.goal),
            ))),
        Positioned.fill(
          child: widget.goal.subGoals.isNotEmpty
              ? PageView(
                  children: [
                    ...widget.goal.subGoals
                        .map((e) => Hero(
                            tag: e.id,
                            child: GoalTitle(e, key: ValueKey(e.id))))
                        .toList(),
                    AddSubGoalCard(onGoalText: (text) {
                      setState(() {
                        widget.goal.addSubGoal(
                            Goal(text: text, id: const Uuid().v4()));
                      });
                    }, onError: (e) {
                      log(e.toString());
                    }),
                  ],
                )
              : const Center(
                  child: Text('Nothin\' to it but to do it.'),
                ),
        ),
      ],
    );
  }
}
