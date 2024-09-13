import 'dart:io';

import 'package:flutter/foundation.dart';

isMacOS() {
  if (kIsWeb) {
    return defaultTargetPlatform == TargetPlatform.macOS;
  }
  return Platform.isMacOS;
}
