import 'package:flutter/widgets.dart'
    show InheritedWidget, Widget, BuildContext;

import 'stt_service.dart' show SttService;

class AppContext extends InheritedWidget {
  final SttService sttService;
  AppContext({
    super.key,
    required super.child,
    required this.sttService,
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
