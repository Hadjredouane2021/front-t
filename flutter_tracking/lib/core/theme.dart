import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'status.dart';

/// Design tokens — style "app de livraison" : clair, jaune vif + vert, formes très arrondies.
abstract final class AppColors {
  static const bg = Color(0xFFF4F4F2);
  static const card = Colors.white;
  static const surface = Color(0xFFF4F4F2);
  static const surfaceStrong = Color(0xFFEAEAE6);
  static const border = Color(0xFFE8E8E4);
  static const borderStrong = Color(0xFFD6D6D0);
  static const text = Color(0xFF1D1D1B);
  static const textMuted = Color(0xFF6B6B66);
  static const textFaint = Color(0xFF9E9E98);

  /// Jaune signature (CTA, header, sélection).
  static const yellow = Color(0xFFFFC244);
  static const yellowSoft = Color(0xFFFFF3D6);

  /// Vert signature (disponible, actions positives).
  static const green = Color(0xFF00A082);
  static const greenSoft = Color(0xFFE0F5F0);

  static const available = green;
  static const mission = Color(0xFFF5A300);
  static const unavailable = Color(0xFF8E8E88);
  static const offline = Color(0xFFE5484D);
  static const danger = Color(0xFFE5484D);

  static Color tone(StatusTone t) => switch (t) {
    StatusTone.available => available,
    StatusTone.mission => mission,
    StatusTone.unavailable => unavailable,
    StatusTone.offline => offline,
  };

  /// Couleur de texte lisible sur fond clair pour chaque statut.
  static Color toneText(StatusTone t) => switch (t) {
    StatusTone.available => const Color(0xFF007A63),
    StatusTone.mission => const Color(0xFF8F5E00),
    StatusTone.unavailable => const Color(0xFF55554F),
    StatusTone.offline => const Color(0xFFC0272D),
  };

  /// Palette identique au front Angular (carte + sidebar) pour garder les couleurs synchronisées.
  static const markerPalette = <Color>[
    Color(0xFF00F0FF),
    Color(0xFFFFB300),
    Color(0xFFFF3B6B),
    Color(0xFF8B5CF6),
    Color(0xFF22D3EE),
    Color(0xFF34D399),
    Color(0xFFFB7185),
    Color(0xFFF97316),
    Color(0xFFA3E635),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFFFACC15),
  ];

  /// Même hash que `Math.imul(31, h) + charCode | 0` côté TypeScript.
  static int hashUid(String uid) {
    var h = 0;
    for (final c in uid.codeUnits) {
      h = (31 * h + c).toSigned(32);
    }
    return h.abs();
  }

  static Color agent(String uid) => markerPalette[hashUid(uid) % markerPalette.length];

  static Color onColor(Color c) => c.computeLuminance() > 0.45 ? text : Colors.white;
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppShadows {
  static const card = [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -4)];
  static const floating = [
    BoxShadow(color: Color(0x26000000), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -6),
  ];
  static const soft = [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3))];
}

/// Chiffres tabulaires (vitesse, distances, heures) dans la police principale.
TextStyle mono(double size, {Color? color, FontWeight weight = FontWeight.w600}) => GoogleFonts.nunito(
  fontSize: size,
  color: color ?? AppColors.textMuted,
  fontWeight: weight,
  fontFeatures: const [FontFeature.tabularFigures()],
);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.nunito().fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.green,
      secondary: AppColors.yellow,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
  );
  final text = base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  return base.copyWith(
    textTheme: text,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(AppRadii.sm)),
      textStyle: text.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      waitDuration: const Duration(milliseconds: 350),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.borderStrong),
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(4),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.green),
  );
}
