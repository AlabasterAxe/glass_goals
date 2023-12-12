import 'package:flutter/widgets.dart';

class RootSearchAction extends Action {
  final Function() cb;
  RootSearchAction({required this.cb});

  @override
  Object? invoke(Intent intent) {
    return cb();
  }
}
