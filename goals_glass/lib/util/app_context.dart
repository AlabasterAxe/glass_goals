import 'dart:async';

import 'package:async/async.dart' show RestartableTimer;
import 'package:flutter/widgets.dart'
    show AnimationController, BuildContext, InheritedWidget, PageController;
import 'package:goals_core/sync.dart' show SyncClient;
import 'package:rxdart/subjects.dart' show Subject;

import '../stt_service.dart' show SttService;

class AppContext extends InheritedWidget {
  final SttService sttService;
  final SyncClient syncClient;
  final RestartableTimer screenTimeoutTimer;
  final AnimationController backgroundColorAnimationController;

  // This is used to return to the active goal when a goal hint happens
  final PageController rootViewPageController;
  final Subject<void> interactionSubject;

  const AppContext({
    super.key,
    required super.child,
    required this.sttService,
    required this.syncClient,
    required this.screenTimeoutTimer,
    required this.backgroundColorAnimationController,
    required this.interactionSubject,
    required this.rootViewPageController,
  });

  static AppContext of(BuildContext context) {
    final appContext = context.dependOnInheritedWidgetOfExactType<AppContext>();
    if (appContext == null) {
      throw Exception("must have AppContext in ancestry");
    }
    return appContext;
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }
}
