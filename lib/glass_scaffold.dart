import 'dart:developer';

import 'package:flutter/material.dart';

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
          log('vertical drag end');
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
