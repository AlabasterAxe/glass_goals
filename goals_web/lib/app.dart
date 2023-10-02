import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, MaterialApp, Scaffold;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        ConnectionState,
        FutureBuilder,
        Locale,
        Navigator,
        Route,
        SingleTickerProviderStateMixin,
        SizedBox,
        State,
        StatefulWidget,
        StatelessWidget,
        StreamBuilder,
        Widget;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/providers.dart';

import 'app.gr.dart';
import 'app_context.dart';
import 'goal_viewer/goal_viewer.dart';
import 'styles.dart';

class WebGoals extends StatefulWidget {
  final bool shouldAuthenticate;
  final PersistenceService persistenceService;
  const WebGoals({
    super.key,
    this.shouldAuthenticate = true,
    required this.persistenceService,
  });

  @override
  State<WebGoals> createState() => _WebGoalsState();
}

class MyObserver extends AutoRouterObserver {
  _routeChanged(Route<dynamic>? route) {
    if (route?.settings.name != null &&
        route!.settings.name!.contains('goalDetail')) {
      final goalId = route.settings.name!.split('/').last;
      focusedGoalSubject.add(goalId);
    } else {
      focusedGoalSubject.add(null);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeChanged(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeChanged(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeChanged(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _routeChanged(newRoute);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {}
}

@AutoRouterConfig()
class AppRouter extends $AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: Home.page, initial: true, path: '/home', children: [
          CustomRoute(
              page: GoalDetail.page,
              path: 'goal/:goalId',
              durationInMilliseconds: 0,
              reverseDurationInMilliseconds: 0),
        ]),
        AutoRoute(page: SignIn.page, path: '/sign-in'),
      ];
}

class _WebGoalsState extends State<WebGoals>
    with SingleTickerProviderStateMixin {
  late SyncClient syncClient =
      SyncClient(persistenceService: widget.persistenceService);

  Future<void> appInit(context) async {
    await syncClient.init();
    if (FirebaseAuth.instance.currentUser == null &&
        widget.shouldAuthenticate) {
      Navigator.pushReplacementNamed(context, '/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: appInit(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator()));
          }
          return AppContext(
              syncClient: syncClient,
              child: MaterialApp.router(
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('en', 'GB'),
                ],
                routerConfig: AppRouter().config(),
                theme: theme,
              ));
        });
  }
}

@RoutePage(name: 'home')
class GoalsHome extends StatelessWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, Goal>>(
          stream: AppContext.of(context).syncClient.stateSubject,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()));
            }
            return GoalViewerPage(goalMap: snapshot.requireData);
          }),
    );
  }
}
