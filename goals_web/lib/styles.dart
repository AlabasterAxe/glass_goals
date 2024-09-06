import 'package:flutter/material.dart'
    show AppBarTheme, ColorScheme, Colors, ThemeData, Typography;
import 'dart:ui' show FontWeight;
import 'package:flutter/widgets.dart' show Color, TextStyle;
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_split_view/multi_split_view.dart';

uiUnit([double numUnits = 1]) => 4.0 * (numUnits);

const lightBackground = Color(0xFFFEFBF1);
const emphasizedLightBackground = Color.fromARGB(10, 0, 0, 0);

const paleGreenColor = Color(0xFFD0E7C5);
const darkGreenColor = Color(0xFF17300B);
const paleBlueColor = Color(0xFFCCD6EA);
const darkBlueColor = Color(0xFF0C1C60);
const palePurpleColor = Color(0xFFD5CFEA);
const darkPurpleColor = Color(0xFF18065A);
const palePinkColor = Color.fromARGB(255, 227, 205, 220);
const deepRedColor = Color.fromARGB(255, 51, 2, 34);
const yellowColor = Color(0xFFFFEEC4);
const darkBrownColor = Color(0xFF2F2602);
const paleGreyColor = Color.fromARGB(255, 225, 225, 225);
const darkGreyColor = Color.fromARGB(255, 50, 50, 50);

const darkElementColor = darkBlueColor;

final mainTextStyle = TextStyle(fontSize: uiUnit(5), color: darkElementColor);
final smallTextStyle =
    TextStyle(fontSize: uiUnit(3.5), color: darkElementColor);

const focusedFontStyle = TextStyle(fontWeight: FontWeight.bold, inherit: true);

final colorScheme = ColorScheme.fromSeed(
  seedColor: Colors.amber,
).copyWith(primary: Color.fromARGB(255, 139, 104, 0));

final defaultTextTheme = Typography.material2021(colorScheme: colorScheme)
    .black
    .copyWith(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
    )
    .apply(
      fontFamily: defaultFont.fontFamily,
      bodyColor: defaultFont.color,
      displayColor: defaultFont.color,
    );

final theme = ThemeData(
  useMaterial3: true,
  // navy
  colorScheme: colorScheme,
  primaryTextTheme: defaultTextTheme,
  textTheme: defaultTextTheme,
  typography: Typography.material2021().copyWith(black: defaultTextTheme),
);

final defaultFont = TextStyle(
    color: darkElementColor,
    fontFamily: GoogleFonts.getFont('Jost').fontFamily);

final enormousTitleTextStyle = TextStyle(
    fontSize: uiUnit(15),
    fontWeight: FontWeight.bold,
    color: darkElementColor,
    fontFamily:
        GoogleFonts.getFont('Jost', fontWeight: FontWeight.w500).fontFamily);

final multiSplitViewThemeData = MultiSplitViewThemeData(
    dividerThickness: uiUnit(2),
    dividerPainter: DividerPainters.dashed(
        size: 1000000000000, thickness: 3, color: darkElementColor));
