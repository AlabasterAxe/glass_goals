import 'dart:async' show StreamSubscription, Timer;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, MaterialApp, Scaffold;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        ConnectionState,
        FutureBuilder,
        GlobalKey,
        Locale,
        MouseRegion,
        NavigatorState,
        SingleTickerProviderStateMixin,
        SizedBox,
        StatelessWidget,
        StreamBuilder,
        Widget;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/common/cloudstore_service.dart';
import 'package:goals_web/common/constants.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/widgets/unanimated_route.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_context.dart';
import 'goal_viewer/goal_viewer.dart';
import 'landing_page.dart';
import 'styles.dart';
import 'package:universal_html/html.dart';

class WebGoals extends ConsumerStatefulWidget {
  final bool shouldAuthenticate;
  final PersistenceService persistenceService;
  final bool debug;
  const WebGoals({
    super.key,
    this.shouldAuthenticate = true,
    required this.persistenceService,
    this.debug = false,
  });

  @override
  ConsumerState<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends ConsumerState<WebGoals>
    with SingleTickerProviderStateMixin {
  late final SyncClient _syncClient =
      SyncClient(persistenceService: this.widget.persistenceService);

  late final CloudstoreService _cloudstoreService = CloudstoreService(
    storage: FirebaseStorage.instance,
    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
  );

  // responsible for updating the world state so the UI updates according with the current time
  late Timer _refreshTimer;

  late StreamSubscription _stateSubscription;
  late StreamSubscription _userSubscription;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final _appInitFuture = _appInit(context);

  bool _hasMouse = false;

  void initState() {
    super.initState();
    this._userSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && this.widget.shouldAuthenticate) {
        this.navigatorKey.currentState?.pushReplacementNamed('/');
      } else if (user != null) {
        this.navigatorKey.currentState?.pushReplacementNamed('/home');
      }
    });

    document.onContextMenu.listen((event) => event.preventDefault());
  }

  Future<void> _appInit(context) async {
    await this._syncClient.init();
    final uiState = await Hive.openBox(UI_STATE_BOX);

    _hasMouse = uiState.get(UI_STATE_HAS_MOUSE_KEY, defaultValue: false);
    ref.read(hasMouseProvider.notifier).set(_hasMouse);

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      worldContextStream.add(WorldContext.now());
    });
    _stateSubscription = this
        ._syncClient
        .stateSubject
        .asBroadcastStream()
        .listen((Map<String, Goal> goalMap) {
      worldContextStream.add(WorldContext.now());
    });
    this.ref.read(debugProvider.notifier).set(this.widget.debug);
  }

  @override
  void dispose() {
    this._refreshTimer.cancel();
    this._stateSubscription.cancel();
    this._userSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contents = AppContext(
      syncClient: this._syncClient,
      cloudstoreService: this._cloudstoreService,
      child: MaterialApp(
          navigatorKey: this.navigatorKey,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en', 'GB'),
          ],
          initialRoute: FirebaseAuth.instance.currentUser == null &&
                  this.widget.shouldAuthenticate
              ? '/'
              : '/home',
          theme: theme,
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name == '/') {
              return UnanimatedPageRoute(
                  builder: (context) => LandingPage(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/register')) {
              return UnanimatedPageRoute(
                  builder: (context) => RegisterScreen(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/sign-in')) {
              return UnanimatedPageRoute(
                  builder: (context) => SignInScreen(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/home')) {
              return UnanimatedPageRoute(
                  builder: (context) => FutureBuilder<void>(
                      future: _appInitFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator()));
                        }
                        return GoalsHome();
                      }),
                  settings: settings);
            }
          }),
    );
    return this._hasMouse
        ? contents
        : MouseRegion(
            onHover: (event) async {
              if (event.kind == PointerDeviceKind.mouse) {
                ref.read(hasMouseProvider.notifier).set(true);
                setState(() {
                  this._hasMouse = true;
                });
                (await Hive.openBox(UI_STATE_BOX))
                    .put(UI_STATE_HAS_MOUSE_KEY, true);
              }
            },
            child: contents);
  }
}

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
            return GoalViewer(goalMap: snapshot.requireData);
          }),
    );
  }
}
