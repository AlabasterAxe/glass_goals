import 'package:flutter/services.dart';

const CTRL_KEYS = [
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight
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
