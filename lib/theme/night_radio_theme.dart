import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The global Finamp Night visual system.
///
/// The palette intentionally stays fixed instead of following album artwork or
/// the system accent. That keeps every screen legible and gives the app the
/// same low-glare radio-console identity in the library, settings, and player.
abstract final class NightRadioColors {
  static const background = Color(0xFF050609);
  static const surface = Color(0xFF0A0C11);
  static const surfaceRaised = Color(0xFF11141B);
  static const surfaceBright = Color(0xFF171B24);
  static const violet = Color(0xFFA970FF);
  static const violetDim = Color(0xFF2C1D42);
  static const cyan = Color(0xFF65E8FF);
  static const amber = Color(0xFFFFB84D);
  static const signal = Color(0xFF9DFF6B);
  static const text = Color(0xFFF1EFF7);
  static const textMuted = Color(0xFF9B97A8);
  static const outline = Color(0xFF34303F);
}

const nightRadioColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: NightRadioColors.violet,
  onPrimary: Color(0xFF160D24),
  primaryContainer: NightRadioColors.violetDim,
  onPrimaryContainer: Color(0xFFE9D8FF),
  secondary: NightRadioColors.cyan,
  onSecondary: Color(0xFF001F25),
  secondaryContainer: Color(0xFF07323A),
  onSecondaryContainer: Color(0xFFB8F5FF),
  tertiary: NightRadioColors.amber,
  onTertiary: Color(0xFF2A1800),
  tertiaryContainer: Color(0xFF3E2A0C),
  onTertiaryContainer: Color(0xFFFFD9A0),
  error: Color(0xFFFF6B7D),
  onError: Color(0xFF31000A),
  errorContainer: Color(0xFF5A1522),
  onErrorContainer: Color(0xFFFFD9DE),
  surface: NightRadioColors.surface,
  onSurface: NightRadioColors.text,
  onSurfaceVariant: NightRadioColors.textMuted,
  outline: NightRadioColors.outline,
  outlineVariant: Color(0xFF211F29),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: NightRadioColors.text,
  onInverseSurface: NightRadioColors.background,
  inversePrimary: Color(0xFF65439B),
  surfaceTint: NightRadioColors.violet,
);

ThemeData buildNightRadioTheme({PageTransitionsTheme? pageTransitionsTheme}) {
  const compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(5)),
    side: BorderSide(color: NightRadioColors.outline),
  );
  const panelShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(7)));
  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(5)),
    borderSide: BorderSide(color: NightRadioColors.outline),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: nightRadioColorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: NightRadioColors.surface,
    cardColor: NightRadioColors.surfaceRaised,
    dividerColor: NightRadioColors.outline,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: const VisualDensity(horizontal: -0.5, vertical: -0.5),
    pageTransitionsTheme: pageTransitionsTheme,
  );

  final textTheme = base.textTheme
      .apply(bodyColor: NightRadioColors.text, displayColor: NightRadioColors.text)
      .copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.35),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.35),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          color: NightRadioColors.textMuted,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.15,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    iconTheme: const IconThemeData(color: NightRadioColors.text, size: 22),
    primaryIconTheme: const IconThemeData(color: NightRadioColors.violet, size: 22),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Color(0xF207080C),
      foregroundColor: NightRadioColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: NightRadioColors.text,
        fontFamily: 'monospace',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarColor: NightRadioColors.background,
      ),
    ),
    cardTheme: const CardThemeData(
      color: NightRadioColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: compactShape,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NightRadioColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: panelShape,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NightRadioColors.surfaceRaised,
      modalBackgroundColor: NightRadioColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: NightRadioColors.outline),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: NightRadioColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
        side: BorderSide(color: NightRadioColors.outline),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: NightRadioColors.textMuted,
      textColor: NightRadioColors.text,
      selectedColor: NightRadioColors.cyan,
      selectedTileColor: Color(0x292C1D42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      contentPadding: EdgeInsets.symmetric(horizontal: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: NightRadioColors.cyan,
      unselectedLabelColor: NightRadioColors.textMuted,
      indicatorColor: NightRadioColors.violet,
      dividerColor: NightRadioColors.outline,
      labelStyle: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      backgroundColor: const Color(0xF20A0C11),
      surfaceTintColor: Colors.transparent,
      indicatorColor: NightRadioColors.violet.withValues(alpha: 0.24),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: NightRadioColors.surfaceRaised,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        borderSide: BorderSide(color: NightRadioColors.violet, width: 1.2),
      ),
      labelStyle: TextStyle(color: NightRadioColors.textMuted, fontFamily: 'monospace'),
      hintStyle: TextStyle(color: NightRadioColors.textMuted),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: NightRadioColors.violet,
      inactiveTrackColor: NightRadioColors.outline,
      secondaryActiveTrackColor: NightRadioColors.cyan,
      thumbColor: NightRadioColors.cyan,
      overlayColor: Color(0x29A970FF),
      trackHeight: 3,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NightRadioColors.violet,
      linearTrackColor: NightRadioColors.outline,
      circularTrackColor: NightRadioColors.outline,
    ),
    dividerTheme: const DividerThemeData(color: NightRadioColors.outline, thickness: 0.7, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: NightRadioColors.surfaceRaised,
      selectedColor: NightRadioColors.violetDim,
      side: const BorderSide(color: NightRadioColors.outline),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: NightRadioColors.text),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: NightRadioColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: compactShape,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NightRadioColors.surfaceBright,
      contentTextStyle: TextStyle(color: NightRadioColors.text),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: compactShape,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NightRadioColors.violetDim,
        foregroundColor: NightRadioColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: compactShape,
        textStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NightRadioColors.violet,
        foregroundColor: const Color(0xFF160D24),
        shape: compactShape,
        textStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NightRadioColors.cyan,
        side: const BorderSide(color: NightRadioColors.outline),
        shape: compactShape,
        textStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NightRadioColors.violet,
      foregroundColor: Color(0xFF160D24),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(7))),
    ),
  );
}

class NightRadioAppShell extends StatelessWidget {
  const NightRadioAppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NightRadioColors.background,
      child: RepaintBoundary(
        child: CustomPaint(painter: const _NightRadioBackdropPainter(), child: child),
      ),
    );
  }
}

class _NightRadioBackdropPainter extends CustomPainter {
  const _NightRadioBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.75, -0.9),
        radius: 1.4,
        colors: [Color(0x222C1650), Color(0x0D0A3140), Colors.transparent],
        stops: [0, 0.48, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final scanline = Paint()..color = const Color(0x08FFFFFF);
    for (double y = 1; y < size.height; y += 5) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 0.5), scanline);
    }
  }

  @override
  bool shouldRepaint(covariant _NightRadioBackdropPainter oldDelegate) => false;
}
