import 'package:flutter/material.dart'
    show AppBarTheme, ColorScheme, Colors, ThemeData, Typography;
import 'dart:ui' show FontWeight;
import 'package:flutter/widgets.dart' show Color, TextStyle;
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_split_view/multi_split_view.dart';

uiUnit([double numUnits = 1]) => 4.0 * (numUnits);

const lightBackground = Color(0xFFFEFBF1);
const emphasizedLightBackground = Color.fromARGB(255, 255, 254, 251);

const paleGreenColor = Color.fromARGB(255, 208, 231, 197);
const darkGreenColor = Color.fromARGB(255, 23, 48, 11);
const paleBlueColor = Color.fromARGB(255, 204, 214, 234);
const darkBlueColor = Color.fromARGB(255, 12, 28, 96);
const palePurpleColor = Color.fromARGB(255, 213, 207, 234);
const darkPurpleColor = Color.fromARGB(255, 24, 6, 90);
const palePinkColor = Color.fromARGB(255, 227, 205, 220);
const deepRedColor = Color.fromARGB(255, 51, 2, 34);
const yellowColor = Color.fromARGB(255, 255, 238, 196);
const darkBrownColor = Color.fromARGB(255, 47, 38, 2);
const paleGreyColor = Color.fromARGB(255, 225, 225, 225);
const darkGreyColor = Color.fromARGB(255, 50, 50, 50);

const darkElementColor = darkBlueColor;

final mainTextStyle = TextStyle(fontSize: uiUnit(5), color: darkElementColor);
final smallTextStyle =
    TextStyle(fontSize: uiUnit(3.5), color: darkElementColor);

const focusedFontStyle = TextStyle(fontWeight: FontWeight.bold, inherit: true);

final colorScheme = ColorScheme.fromSwatch(
  primarySwatch: Colors.amber,
  backgroundColor: lightBackground,
).copyWith(primary: Color.fromARGB(255, 139, 104, 0));

final defaultTextTheme =
    Typography.material2021(colorScheme: colorScheme).black.apply(
          fontFamily: defaultFont.fontFamily,
          bodyColor: defaultFont.color,
          displayColor: defaultFont.color,
        );

final theme = ThemeData(
  useMaterial3: true,
  // navy
  colorScheme: colorScheme,
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
