import 'package:flutter/widgets.dart' show BuildContext, InheritedWidget;
import 'package:goals_core/sync.dart' show SyncClient;
import 'package:goals_web/common/cloudstore_service.dart';

class AppContext extends InheritedWidget {
  final SyncClient syncClient;
  final CloudstoreService cloudstoreService;

  const AppContext({
    super.key,
    required super.child,
    required this.syncClient,
    required this.cloudstoreService,
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
