import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:rxdart/rxdart.dart' show PublishSubject, Subject;
import 'package:screen_brightness/screen_brightness.dart' show ScreenBrightness;

import 'goals/goal_card.dart';
import 'goals/goal_hierarchy.dart';
import 'goals/goal_list.dart';
import 'util/app_context.dart' show AppContext;
import 'settings/settings_widget.dart';
import 'styles.dart' show mainTextStyle;
import 'util/glass_gesture_detector.dart';
import 'util/glass_page_view.dart' show GlassPageView;
import 'util/glass_scaffold.dart';
import 'package:goals_core/model.dart'
    show
        Goal,
        WorldContext,
        getActiveGoalExpiringSoonest,
        getGoalsRequiringAttention,
        getTransitiveSubGoals;
import 'stt_service.dart' show SttService;
import 'package:goals_core/sync.dart'
    show SyncClient, GoogleSheetsPersistenceService;

void main() {
  runApp(const GlassGoals());
}

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key});

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals>
    with SingleTickerProviderStateMixin {
  SttService sttService = SttService();
  SyncClient syncClient =
      SyncClient(persistenceService: GoogleSheetsPersistenceService());
  RestartableTimer screenOffTimer =
      RestartableTimer(const Duration(seconds: 10), () {
    ScreenBrightness().setScreenBrightness(0.0);
  });
  late AnimationController backgroundColorAnimationController =
      AnimationController(vsync: this);
  Subject interactionSubject = PublishSubject<void>();
  PageController rootPageController = PageController();

  Future<void> appInit() async {
    await Hive.initFlutter();
    await Hive.openBox('glass_goals.settings');
    await syncClient.init();
    Timer.periodic(const Duration(minutes: 10), (_) {
      final hintingEnabled = Hive.box('glass_goals.settings')
          .get('enableHinting', defaultValue: true);
      if (hintingEnabled) {
        ScreenBrightness().setScreenBrightness(1.0);
        screenOffTimer.reset();
        backgroundColorAnimationController.forward().then((_) {
          rootPageController.jumpTo(0.0);
          backgroundColorAnimationController.reverse();
        });
      }
    });
    backgroundColorAnimationController.value = 0.0;
    backgroundColorAnimationController.duration = const Duration(seconds: 10);
    interactionSubject.listen((_) {
      ScreenBrightness().setScreenBrightness(1.0);
      screenOffTimer.reset();
      backgroundColorAnimationController.animateBack(0.0,
          duration: const Duration(milliseconds: 300));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: appInit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
                home: Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator()))));
          }
          return AppContext(
              sttService: sttService,
              syncClient: syncClient,
              screenTimeoutTimer: screenOffTimer,
              backgroundColorAnimationController:
                  backgroundColorAnimationController,
              interactionSubject: interactionSubject,
              rootViewPageController: rootPageController,
              child: MaterialApp(
                title: 'Glass Goals',
                theme: ThemeData(
                  primaryColor: Colors.black,
                  textTheme: const TextTheme(
                    bodyText1: TextStyle(color: Colors.white),
                    bodyText2: TextStyle(color: Colors.white),
                    headline1: mainTextStyle,
                  ),
                ),
                home: const GoalsHome(),
              ));
        });
  }
}

class GoalsHome extends StatefulWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  State<GoalsHome> createState() => _GoalsHomeState();
}

class _GoalsHomeState extends State<GoalsHome> {
  bool isInitted = false;
  Function? cleanup;

  handleHinting(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitted) {
      isInitted = true;
      final hintAnimationController =
          AppContext.of(context).backgroundColorAnimationController;
      hintAnimationController.addStatusListener(handleHinting);

      cleanup = () {
        hintAnimationController.removeStatusListener(handleHinting);
      };
    }
  }

  @override
  void dispose() {
    super.dispose();
    cleanup?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bgAnimation =
        AppContext.of(context).backgroundColorAnimationController;
    return AnimatedBuilder(
      animation: bgAnimation,
      builder: (context, child) {
        return GlassScaffold(child: child);
      },
      child: GlassPageView(
        controller: AppContext.of(context).rootViewPageController,
        children: [
          StreamBuilder<Map<String, Goal>>(
              stream: AppContext.of(context).syncClient.stateSubject,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                      child: Text("Loading Active Goal",
                          style: Theme.of(context).textTheme.headline1));
                }

                final unarchivedGoals =
                    getTransitiveSubGoals(snapshot.requireData, 'root');
                final activeGoal = getActiveGoalExpiringSoonest(
                    WorldContext.now(), unarchivedGoals);
                return activeGoal == null
                    ? Center(
                        child: Text("No Active Goal",
                            style: Theme.of(context).textTheme.headline1))
                    : GoalCard(
                        goal: activeGoal,
                        onBack: () {
                          SystemNavigator.pop();
                        });
              }),
          GlassGestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StreamBuilder<Map<String, Goal>>(
                            stream:
                                AppContext.of(context).syncClient.stateSubject,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator()));
                              }
                              return GlassScaffold(
                                  child: GoalHierarchy(snapshot.requireData,
                                      rootGoalId: 'root'));
                            })));
              },
              child: Center(
                  child: Text("Goals",
                      style: Theme.of(context).textTheme.headline1))),
          GlassGestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StreamBuilder<Map<String, Goal>>(
                            stream:
                                AppContext.of(context).syncClient.stateSubject,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator()));
                              }
                              return GlassScaffold(
                                  child: GoalList(getGoalsRequiringAttention(
                                      WorldContext.now(),
                                      snapshot.requireData)));
                            })));
              },
              child: Center(
                  child: Text("Review",
                      style: Theme.of(context).textTheme.headline1))),
          GlassGestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const GlassScaffold(child: SettingsWidget())));
              },
              child: Center(
                  child: Text("Settings",
                      style: Theme.of(context).textTheme.headline1)))
        ],
      ),
    );
  }
}
