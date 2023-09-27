import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart' show TextStyle;

uiUnit([int numUnits = 1]) => 4.0 * (numUnits);
final mainTextStyle = TextStyle(fontSize: uiUnit(5), color: Colors.black);
final smallTextStyle = TextStyle(fontSize: uiUnit(3), color: Colors.black);
