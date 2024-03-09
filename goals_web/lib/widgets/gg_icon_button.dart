import 'package:flutter/material.dart';
import 'package:goals_web/styles.dart';

class GlassGoalsIconButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onPressed;
  final Widget? iconWidget;
  const GlassGoalsIconButton(
      {super.key, this.icon, required this.onPressed, this.iconWidget});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: uiUnit(8),
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: icon != null
            ? Icon(icon, color: darkElementColor, size: 24)
            : iconWidget!,
        onPressed: onPressed,
      ),
    );
    ;
  }
}
