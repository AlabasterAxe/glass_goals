import 'dart:ui';

import 'package:flutter/services.dart' show SystemNavigator;
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
import 'package:wakelock/wakelock.dart' show Wakelock;

import 'app_context.dart';

class GlassScaffold extends StatelessWidget {
  final Widget? child;

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
            AppContext.of(context).interactionSubject.add(null);
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 10) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                SystemNavigator.pop();
              }
            }
          },
          child: child,
        ),
        builder: (context, child) {
          Wakelock.enable();
          return Scaffold(
            backgroundColor:
                Color.lerp(Colors.black, Colors.white, bgAnimation.value),
            body: child,
          );
        });
  }
}
