import 'package:flutter/material.dart' show IconButton, Icons;
import 'package:flutter/rendering.dart' show MainAxisAlignment;
import 'package:flutter/widgets.dart'
    show BuildContext, Icon, Row, SizedBox, StatelessWidget, Widget;
import 'package:goals_web/goal_viewer/providers.dart';

import '../styles.dart';

class TextEditingControls extends StatelessWidget {
  const TextEditingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: uiUnit(15),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              editingEventStream.add(EditingEvent.discard);
            },
          ),
        ),
        SizedBox(
          width: uiUnit(15),
          child: IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              editingEventStream.add(EditingEvent.accept);
            },
          ),
        )
      ],
    );
  }
}
