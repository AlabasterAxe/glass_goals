import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'styles.dart';
import 'widgets/gg_button.dart';

GlassGoalsAppBar({
  String appBarTitle = "Glass Goals",
  bool isNarrow = false,
  String? focusedGoalId,
  VoidCallback? onBack,
  required bool signedIn,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    surfaceTintColor: Colors.transparent,
    title: Row(
      children: [
        if (!isNarrow)
          SizedBox(
            width: uiUnit(12),
            height: uiUnit(12),
            child: Padding(
              padding: EdgeInsets.only(
                  top: uiUnit(2), right: uiUnit(2), bottom: uiUnit(2)),
              child: SvgPicture.asset(
                'assets/logo.svg',
              ),
            ),
          ),
        Text(appBarTitle),
      ],
    ),
    centerTitle: false,
    bottom: PreferredSize(
        preferredSize: Size.fromHeight(uiUnit(2)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: uiUnit(2)),
          child: Container(
            color: darkBlueColor,
            height: uiUnit(2),
          ),
        )),
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
    actions: [
      if (!isNarrow)
        Builder(builder: (context) {
          return Padding(
            padding: EdgeInsets.only(right: uiUnit(2)),
            child: signedIn
                ? GlassGoalsButton(
                    child: Text("SIGN OUT"),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    })
                : GlassGoalsButton(
                    child: Text("SIGN IN"),
                    onPressed: () => Navigator.pushNamed(context, '/sign-in')),
          );
        }),
    ],
  );
}
