import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_screen.dart';

void main() {
  runApp(const JahraApp());
}

/// ألوان التطبيق
class AppColors {
  static const g0 = Color(0xFF2E4A1C);
  static const g1 = Color(0xFF3E5F22);
  static const g2 = Color(0xFF557A35);
  static const gold = Color(0xFFD9B44A);
  static const ink = Colors.white;
  static const inkDim = Color(0xBBFFFFFF);
  static const hiInk = Color(0xFF14200C);
  static const bands = [
    Color(0xFF46672A),
    Color(0xFF5A7F37),
    Color(0xFF729943),
    Color(0xFF86AE4B),
  ];
}

class JahraApp extends StatelessWidget {
  const JahraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.g1,
        brightness: Brightness.dark,
        primary: AppColors.gold,
      ),
      scaffoldBackgroundColor: AppColors.g1,
      useMaterial3: true,
    );
    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme('IBM Plex Sans Arabic', base.textTheme);
    } catch (_) {
      textTheme = base.textTheme; // خط الجهاز الافتراضي
    }
    return MaterialApp(
      title: 'مواقيت الجهراء',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: textTheme,
      ),
      home: const HomeScreen(),
    );
  }
}
