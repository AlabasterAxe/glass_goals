import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'styles.dart';

GlassGoalsAppBar({
  String appBarTitle = "Glass Goals",
  bool isNarrow = false,
  String? focusedGoalId,
  VoidCallback? onBack,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    surfaceTintColor: Colors.transparent,
    title: Row(
      children: [
        SizedBox(
          width: uiUnit(12),
          height: uiUnit(12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, uiUnit(2), uiUnit(2), uiUnit(2)),
            child: SvgPicture.asset(
              'assets/logo.svg',
            ),
          ),
        ),
        Text(appBarTitle),
      ],
    ),
    centerTitle: false,
    leading: isNarrow
        ? focusedGoalId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : Builder(builder: (context) {
                return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    });
              })
        : null,
  );
}
