import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:goals_web/common/keyboard_utils.dart';

const SIMULATED_RELEASE_DELAY = Duration(milliseconds: 100);

fixEnterStuckIssue() {
  if (kIsWeb) {
    HardwareKeyboard.instance.addHandler((ev) {
      if (ev.logicalKey == LogicalKeyboardKey.enter &&
          ev is KeyDownEvent &&
          isMetaHeld()) {
        Future.delayed(SIMULATED_RELEASE_DELAY, () {
          if (HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.enter)) {
            HardwareKeyboard.instance.handleKeyEvent(KeyUpEvent(
                physicalKey: ev.physicalKey,
                logicalKey: ev.logicalKey,
                timeStamp: ev.timeStamp + SIMULATED_RELEASE_DELAY));
          }
        });
      }
      return false;
    });
  }
}
