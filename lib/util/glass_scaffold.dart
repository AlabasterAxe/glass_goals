import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show
        AnimatedBuilder,
        BuildContext,
        GestureDetector,
        HitTestBehavior,
        Navigator,
        StatelessWidget,
        Widget;

import 'package:flutter/material.dart' show Scaffold, Colors;

import '../app_context.dart';

class GlassScaffold extends StatelessWidget {
  final Widget child;

  const GlassScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bgAnimation =
        AppContext.of(context).backgroundColorAnimationController;
    return AnimatedBuilder(
        animation: bgAnimation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 10) {
              Navigator.pop(context);
            }
          },
          child: child,
        ),
        builder: (context, child) {
          return Scaffold(
            backgroundColor:
                Color.lerp(Colors.black, Colors.white, bgAnimation.value),
            body: child,
          );
        });
  }
}
