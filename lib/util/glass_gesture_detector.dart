import 'package:flutter/widgets.dart'
    show
        BuildContext,
        DragEndDetails,
        GestureDetector,
        HitTestBehavior,
        StatelessWidget,
        Widget;
import 'package:screen_brightness/screen_brightness.dart';

import '../app_context.dart' show AppContext;

class GlassGestureDetector extends StatelessWidget {
  final Widget child;
  final void Function()? onTap;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  const GlassGestureDetector(
      {super.key, required this.child, this.onTap, this.onVerticalDragEnd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap != null
          ? () {
              ScreenBrightness().setScreenBrightness(1.0);
              AppContext.of(context).screenTimeoutTimer.reset();
              onTap?.call();
            }
          : null,
      onVerticalDragEnd: onVerticalDragEnd != null
          ? (details) {
              ScreenBrightness().setScreenBrightness(1.0);
              AppContext.of(context).screenTimeoutTimer.reset();
              onVerticalDragEnd?.call(details);
            }
          : null,
      child: child,
    );
  }
}
