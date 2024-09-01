import 'package:flutter/material.dart';
import 'package:goals_web/styles.dart';

class GlassGoalsIconButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed;
  final Widget? iconWidget;
  final bool? enabled;
  const GlassGoalsIconButton(
      {super.key,
      this.icon,
      required this.onPressed,
      this.onLongPressed,
      this.iconWidget,
      this.enabled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: uiUnit(8),
      height: uiUnit(8),
      child: GestureDetector(
        onLongPress: onLongPressed,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: icon != null
              ? Icon(icon, color: darkElementColor, size: uiUnit(6))
              : iconWidget!,
          onPressed: this.enabled != false ? onPressed : null,
        ),
      ),
    );
    ;
  }
}
