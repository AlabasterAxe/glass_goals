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
import 'package:glass_goals/styles.dart' show mainTextStyle;

import 'app_context.dart' show AppContext;
import 'model.dart' show Goal;

import 'stt_service.dart' show SttState;

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
  final Goal goal;
  const AddSubGoalCard(this.goal, {super.key});

  @override
  State<AddSubGoalCard> createState() => _AddSubGoalCardState();
}

class _AddSubGoalCardState extends State<AddSubGoalCard> {
  Stream<String>? recordingStream;

  @override
  Widget build(BuildContext context) {
    final stt = AppContext.of(context).sttService;

    return StreamBuilder<SttState>(
        stream: stt.stateSubject,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            switch (snapshot.data) {
              case SttState.unavailable:
                return Container(
                  color: Colors.red,
                  child: const Center(child: Text('Uninitialized')),
                );
              case SttState.uninitialized:
                return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await stt.init();
                    },
                    child: const Center(
                        child:
                            Text('tap to initialize', style: mainTextStyle)));
              case SttState.ready:
                return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      setState(() {
                        recordingStream = stt.detectSpeech();
                      });
                    },
                    child: const Center(
                        child: Text('tap to record!', style: mainTextStyle)));
              case SttState.listening:
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    stt.stop();
                    recordingStream = null;
                  },
                  child: Center(
                      child: StreamBuilder<String>(
                          stream: recordingStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(snapshot.data!);
                            }
                            return const Text('Listening...');
                          })),
                );
              case SttState.initializing:
              case null:
                return const Center(
                    child: SizedBox(
                  child: CircularProgressIndicator(),
                ));
              case SttState.stopping:
                return Container(
                  color: Colors.red,
                  child: const Center(child: Text('Finalizing')),
                );
            }
          }
          return const Center(
              child: SizedBox(
            child: CircularProgressIndicator(),
          ));
        });
  }
}

class GoalWidget extends StatelessWidget {
  final Goal goal;

  const GoalWidget(this.goal, {super.key});

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
              tag: goal.id,
              child: GoalTitle(goal),
            ))),
        Positioned.fill(
          child: goal.subGoals.isNotEmpty
              ? PageView(
                  children: [
                    ...goal.subGoals
                        .map((e) => Hero(
                            tag: e.id,
                            child: GoalTitle(e, key: ValueKey(e.id))))
                        .toList(),
                    AddSubGoalCard(goal),
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
