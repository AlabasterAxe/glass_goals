import 'package:flutter/material.dart'
    show
        AppBarTheme,
        Brightness,
        ColorScheme,
        Colors,
        TextTheme,
        ThemeData,
        Typography;
import 'package:flutter/widgets.dart' show Color, TextStyle;
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_split_view/multi_split_view.dart';

uiUnit([int numUnits = 1]) => 4.0 * (numUnits);

const darkElementColor = Color.fromARGB(255, 12, 28, 96);

final mainTextStyle = TextStyle(fontSize: uiUnit(5), color: darkElementColor);
final smallTextStyle = TextStyle(fontSize: uiUnit(3), color: darkElementColor);

const lightBackground = Color.fromARGB(255, 249, 246, 237);

final defaultTextTheme = Typography.material2021().black.apply(
      fontFamily: defaultFont.fontFamily,
      bodyColor: defaultFont.color,
      displayColor: defaultFont.color,
    );

final theme = ThemeData(
  useMaterial3: true,
  // navy
  colorScheme: ColorScheme.fromSwatch(
    backgroundColor: lightBackground,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: lightBackground,
    foregroundColor: darkElementColor,
  ),
  primaryTextTheme: defaultTextTheme,
  textTheme: defaultTextTheme,
  typography: Typography.material2021().copyWith(black: defaultTextTheme),
);

final defaultFont = TextStyle(
    color: darkElementColor,
    fontFamily: GoogleFonts.getFont('Jost').fontFamily);

final multiSplitViewThemeData = MultiSplitViewThemeData(
    dividerThickness: uiUnit(2),
    dividerPainter: DividerPainters.dashed(
        size: 1000000000000, thickness: 2, color: darkElementColor));
