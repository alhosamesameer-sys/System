import 'package:flutter/material.dart';

class ArsadTheme {
  static const navy = Color(0xFF073B78);
  static const blue = Color(0xFF0866D5);
  static const green = Color(0xFF19A66A);
  static const red = Color(0xFFD92D3A);
  static const canvas = Color(0xFFF3F6FC);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue, secondary: green, surface: Colors.white, error: red),
    appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(color: Colors.white, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDCE4F2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDCE4F2))),
    ),
  );
}
