import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const VisitePvApp());
}

class VisitePvApp extends StatelessWidget {
  const VisitePvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final couleurPrincipale = const Color(0xFF1E6E4C);
    return MaterialApp(
      title: 'Visites PV & Batterie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: couleurPrincipale),
        appBarTheme: AppBarTheme(
          backgroundColor: couleurPrincipale,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: couleurPrincipale,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
