import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../styles.dart';

class GoalSeparator extends StatelessWidget {
  const GoalSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: darkElementColor,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
