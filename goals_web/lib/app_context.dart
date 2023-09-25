import 'package:flutter/widgets.dart' show BuildContext, InheritedWidget;
import 'package:goals_core/sync.dart' show SyncClient;

class AppContext extends InheritedWidget {
  final SyncClient syncClient;

  const AppContext({
    super.key,
    required super.child,
    required this.syncClient,
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
