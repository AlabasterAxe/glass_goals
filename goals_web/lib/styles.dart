import 'package:flutter/material.dart'
    show AppBarTheme, Brightness, ColorScheme, Colors, ThemeData, Typography;
import 'package:flutter/widgets.dart' show Color, TextStyle;
import 'package:multi_split_view/multi_split_view.dart';
import 'package:google_fonts/google_fonts.dart';

uiUnit([int numUnits = 1]) => 4.0 * (numUnits);
final mainTextStyle = TextStyle(fontSize: uiUnit(5), color: Colors.black);
final smallTextStyle = TextStyle(fontSize: uiUnit(3), color: Colors.black);

const darkElementColor = Color.fromARGB(255, 3, 16, 71);
const lightBackground = Color.fromARGB(255, 249, 246, 237);

final theme = ThemeData(
  useMaterial3: true,
  // navy
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: lightBackground,
    accentColor: Color(0xffff6e40),
    cardColor: Colors.white,
    errorColor: Colors.red,
    brightness: Brightness.light,
  ),
  typography: Typography.material2021().copyWith(
      black: Typography.material2021().black.apply(
            bodyColor: darkElementColor,
            displayColor: darkElementColor,
            fontFamily: GoogleFonts.getFont('Jost').fontFamily,
          )),
  appBarTheme: const AppBarTheme(
    backgroundColor: lightBackground,
    foregroundColor: Colors.black,
  ),
);

final multiSplitViewThemeData = MultiSplitViewThemeData(
    dividerThickness: uiUnit(2),
    dividerPainter: DividerPainters.dashed(
        size: 1000000000000,
        thickness: 2.1,
        color: darkElementColor.withOpacity(0.3)));
