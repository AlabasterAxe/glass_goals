import 'package:flutter/widgets.dart'
    show BuildContext, Center, State, StatefulWidget, Text, Widget, TextStyle;

import '../styles.dart';
import '../util/app_context.dart';
import '../util/glass_gesture_detector.dart';

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

    return GlassGestureDetector(
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
