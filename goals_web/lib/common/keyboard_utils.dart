import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show Intent, LogicalKeySet, ShortcutActivator, SingleActivator;

import '../intents.dart';

const CTRL_KEYS = [
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight
];

const META_KEYS = [
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
];

const SHIFT_KEYS = [
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
];

bool isKeyPressed(LogicalKeyboardKey key) {
  return HardwareKeyboard.instance.logicalKeysPressed.contains(key);
}

bool isCtrlHeld() => CTRL_KEYS.any(isKeyPressed);
bool isShiftHeld() => SHIFT_KEYS.any(isKeyPressed);
bool isMetaHeld() => META_KEYS.any(isKeyPressed);

final _PLATFORM_AGNOSTIC_SHORTCUTS = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.escape): const CancelIntent(),
  SingleActivator(LogicalKeyboardKey.enter): const AcceptIntent(),
  SingleActivator(LogicalKeyboardKey.arrowDown): const NextIntent(),
  SingleActivator(LogicalKeyboardKey.arrowUp): const PreviousIntent(),
  SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
};

final SHORTCUTS = <ShortcutActivator, Intent>{
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
      const SearchIntent(),
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
      const UndoIntent(),
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.keyZ): const RedoIntent(),
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
      const AcceptMultiLineTextIntent(),
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.keyD): const ToggleDebugModeIntent(),
  ..._PLATFORM_AGNOSTIC_SHORTCUTS,
};

final MAC_SHORTCUTS = <ShortcutActivator, Intent>{
  LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
      const SearchIntent(),
  LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
      const UndoIntent(),
  LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.keyZ): const RedoIntent(),
  LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.enter):
      const AcceptMultiLineTextIntent(),
  LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.keyD): const ToggleDebugModeIntent(),
  ..._PLATFORM_AGNOSTIC_SHORTCUTS,
};
