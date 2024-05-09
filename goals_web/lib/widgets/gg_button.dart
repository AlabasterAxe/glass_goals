import 'package:flutter/material.dart';

import '../styles.dart';

class GlassGoalsButton extends StatelessWidget {
  final Widget? child;
  final VoidCallback onPressed;
  const GlassGoalsButton({super.key, this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: darkBlueColor,
        foregroundColor: lightBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiUnit(0.5)),
        ),
      ),
      child: this.child,
      onPressed: this.onPressed,
    );
  }
}
