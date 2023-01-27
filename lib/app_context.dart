import 'dart:async';

import 'package:async/async.dart' show RestartableTimer;
import 'package:flutter/widgets.dart' show InheritedWidget, BuildContext;
import 'package:glass_goals/sync/sync_client.dart' show SyncClient;

import 'stt_service.dart' show SttService;

class AppContext extends InheritedWidget {
  final SttService sttService;
  final SyncClient syncClient;
  final RestartableTimer screenTimeoutTimer;
  AppContext({
    super.key,
    required super.child,
    required this.sttService,
    required this.syncClient,
    required this.screenTimeoutTimer,
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
