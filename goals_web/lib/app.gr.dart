// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i4;
import 'package:flutter/material.dart' as _i5;
import 'package:goals_web/app.dart' as _i2;
import 'package:goals_web/goal_viewer/goal_detail.dart' as _i1;
import 'package:goals_web/sign_in.dart' as _i3;

abstract class $AppRouter extends _i4.RootStackRouter {
  $AppRouter({super.navigatorKey});

  @override
  final Map<String, _i4.PageFactory> pagesMap = {
    GoalDetail.name: (routeData) {
      final pathParams = routeData.inheritedPathParams;
      final args = routeData.argsAs<GoalDetailArgs>(
          orElse: () => GoalDetailArgs(goalId: pathParams.getString('goalId')));
      return _i4.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: _i1.GoalDetailView(
          key: args.key,
          goalId: args.goalId,
        ),
      );
    },
    Home.name: (routeData) {
      return _i4.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i2.GoalsHome(),
      );
    },
    SignIn.name: (routeData) {
      return _i4.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i3.SignInWidget(),
      );
    },
  };
}

/// generated route for
/// [_i1.GoalDetailView]
class GoalDetail extends _i4.PageRouteInfo<GoalDetailArgs> {
  GoalDetail({
    _i5.Key? key,
    required String goalId,
    List<_i4.PageRouteInfo>? children,
  }) : super(
          GoalDetail.name,
          args: GoalDetailArgs(
            key: key,
            goalId: goalId,
          ),
          rawPathParams: {'goalId': goalId},
          initialChildren: children,
        );

  static const String name = 'GoalDetail';

  static const _i4.PageInfo<GoalDetailArgs> page =
      _i4.PageInfo<GoalDetailArgs>(name);
}

class GoalDetailArgs {
  const GoalDetailArgs({
    this.key,
    required this.goalId,
  });

  final _i5.Key? key;

  final String goalId;

  @override
  String toString() {
    return 'GoalDetailArgs{key: $key, goalId: $goalId}';
  }
}

/// generated route for
/// [_i2.GoalsHome]
class Home extends _i4.PageRouteInfo<void> {
  const Home({List<_i4.PageRouteInfo>? children})
      : super(
          Home.name,
          initialChildren: children,
        );

  static const String name = 'Home';

  static const _i4.PageInfo<void> page = _i4.PageInfo<void>(name);
}

/// generated route for
/// [_i3.SignInWidget]
class SignIn extends _i4.PageRouteInfo<void> {
  const SignIn({List<_i4.PageRouteInfo>? children})
      : super(
          SignIn.name,
          initialChildren: children,
        );

  static const String name = 'SignIn';

  static const _i4.PageInfo<void> page = _i4.PageInfo<void>(name);
}
