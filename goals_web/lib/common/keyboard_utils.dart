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
  SingleActivator(LogicalKeyboardKey.keyK, control: true): const SearchIntent(),
  SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
  SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
      const RedoIntent(),
  SingleActivator(LogicalKeyboardKey.enter, control: true):
      const AcceptMultiLineTextIntent(),
  SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true):
      const ToggleDebugModeIntent(),
  ..._PLATFORM_AGNOSTIC_SHORTCUTS,
};

final MAC_SHORTCUTS = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.keyK, meta: true): const SearchIntent(),
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true): const UndoIntent(),
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
      const RedoIntent(),
  SingleActivator(LogicalKeyboardKey.enter, meta: true):
      const AcceptMultiLineTextIntent(),
  SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
      const ToggleDebugModeIntent(),
  ..._PLATFORM_AGNOSTIC_SHORTCUTS,
};
