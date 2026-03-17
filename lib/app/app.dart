import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/data/imperium_app_repository.dart';
import '../features/habits/presentation/habits_home_screen.dart';

class _ImperialScrollBehavior extends MaterialScrollBehavior {
  const _ImperialScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class ImperiumSuiApp extends StatelessWidget {
  const ImperiumSuiApp({super.key, required this.repository});

  final ImperiumAppRepository repository;

  @override
  Widget build(BuildContext context) {
    const imperialGold = Color(0xFFC8A45C);
    const imperialBronze = Color(0xFF8A673A);
    const imperialBurgundy = Color(0xFF5B2027);
    const imperialObsidian = Color(0xFF1B120F);
    const imperialIvory = Color(0xFFF3E7D2);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: imperialGold,
          brightness: Brightness.light,
        ).copyWith(
          primary: imperialGold,
          secondary: imperialBronze,
          tertiary: imperialBurgundy,
          surface: imperialIvory,
          onSurface: imperialObsidian,
          outline: const Color(0xFFAA8A5A),
        );

    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );

    final textTheme = baseTextTheme.copyWith(
      displaySmall: GoogleFonts.cormorantGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0.2,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0.2,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.cormorantGaramond(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.08,
        letterSpacing: 0.2,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        height: 1.45,
        color: colorScheme.onSurface.withValues(alpha: 0.82),
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        height: 1.45,
        color: colorScheme.onSurface.withValues(alpha: 0.68),
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: colorScheme.onSurface,
      ),
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: imperialIvory,
      dividerColor: imperialGold.withValues(alpha: 0.18),
      cardTheme: CardThemeData(
        color: imperialIvory,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: imperialGold.withValues(alpha: 0.16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: imperialIvory),
        ),
        backgroundColor: imperialObsidian,
        indicatorColor: imperialGold.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? imperialGold
              : imperialIvory.withValues(alpha: 0.72);
          return IconThemeData(color: color);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: imperialGold,
          foregroundColor: imperialObsidian,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: imperialObsidian,
          side: BorderSide(color: imperialGold.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'Imperium Sui',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _ImperialScrollBehavior(),
      theme: theme,
      home: HabitsHomeScreen(repository: repository),
    );
  }
}
