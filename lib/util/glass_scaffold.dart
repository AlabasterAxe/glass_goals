import 'package:flutter/widgets.dart'
    show
        StatelessWidget,
        Widget,
        BuildContext,
        GestureDetector,
        HitTestBehavior,
        Navigator;

import 'package:flutter/material.dart' show Scaffold, Colors;

class GlassScaffold extends StatelessWidget {
  final Widget child;

  const GlassScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 10) {
            Navigator.pop(context);
          }
        },
        child: child,
      ),
    );
  }
}
