import 'package:flutter/material.dart';

/// 若澜语义化颜色，按亮/暗两套提供，供组件跟随主题切换。
/// 集中管理散落的硬编码品牌色，使暗色模式下整体不刺眼、可读。
class RuolanColors extends ThemeExtension<RuolanColors> {
  const RuolanColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceVariant2,
    required this.chipBg,
    required this.surfaceSelected,
    required this.primary,
    required this.primaryFg,
    required this.onSurfaceStrong,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.border,
    required this.blockquote,
    required this.codeBg,
    required this.accentWarm,
    required this.avatarUser,
    required this.avatarAssistant,
    required this.errorText,
    required this.errorText2,
    required this.errorBg,
    required this.errorBorder,
    required this.statusOk,
    required this.statusWarn,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceVariant2;
  final Color chipBg;
  final Color surfaceSelected;
  final Color primary;
  final Color primaryFg;
  final Color onSurfaceStrong;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color border;
  final Color blockquote;
  final Color codeBg;
  final Color accentWarm;
  final Color avatarUser;
  final Color avatarAssistant;
  final Color errorText;
  final Color errorText2;
  final Color errorBg;
  final Color errorBorder;
  final Color statusOk;
  final Color statusWarn;

  static const light = RuolanColors(
    background: Color(0xFFFAF7F4),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF5F0EC),
    surfaceVariant2: Color(0xFFF0E0D6),
    chipBg: Color(0xFFF3E9E1),
    surfaceSelected: Color(0xFFEFE3D8),
    primary: Color(0xFF8B5E3C),
    primaryFg: Color(0xFF8B5E3C),
    onSurfaceStrong: Color(0xFF5C3D2E),
    onSurface: Color(0xFF3C3C3C),
    onSurfaceMuted: Color(0xFF9A8F86),
    border: Color(0xFFE0D5CC),
    blockquote: Color(0xFF6B5B4B),
    codeBg: Color(0xFFF3EFEA),
    accentWarm: Color(0xFFFFF3E0),
    avatarUser: Color(0xFF6D9EEB),
    avatarAssistant: Color(0xFFE8C4A8),
    errorText: Color(0xFFC0392B),
    errorText2: Color(0xFF7A4A40),
    errorBg: Color(0xFFFDECEA),
    errorBorder: Color(0xFFE0A89E),
    statusOk: Color(0xFF4CAF50),
    statusWarn: Color(0xFFFF9800),
  );

  static const dark = RuolanColors(
    background: Color(0xFF14110E),
    surface: Color(0xFF2A2521),
    surfaceVariant: Color(0xFF322C27),
    surfaceVariant2: Color(0xFF2E2620),
    chipBg: Color(0xFF332B25),
    surfaceSelected: Color(0xFF3D342C),
    primary: Color(0xFF8B5E3C),
    primaryFg: Color(0xFFC9A88C),
    onSurfaceStrong: Color(0xFFE8D9CC),
    onSurface: Color(0xFFEDE6DF),
    onSurfaceMuted: Color(0xFF9A8F86),
    border: Color(0xFF3D352E),
    blockquote: Color(0xFFB8A99C),
    codeBg: Color(0xFF2E2A26),
    accentWarm: Color(0xFF2E2620),
    avatarUser: Color(0xFF6D9EEB),
    avatarAssistant: Color(0xFF4A3B30),
    errorText: Color(0xFFFF8A80),
    errorText2: Color(0xFFFFAB91),
    errorBg: Color(0xFF3A2420),
    errorBorder: Color(0xFF5A3530),
    statusOk: Color(0xFF81C784),
    statusWarn: Color(0xFFFB8C00),
  );

  static RuolanColors of(BuildContext context) =>
      Theme.of(context).extension<RuolanColors>()!;

  @override
  ThemeExtension<RuolanColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceVariant2,
    Color? chipBg,
    Color? surfaceSelected,
    Color? primary,
    Color? primaryFg,
    Color? onSurfaceStrong,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? border,
    Color? blockquote,
    Color? codeBg,
    Color? accentWarm,
    Color? avatarUser,
    Color? avatarAssistant,
    Color? errorText,
    Color? errorText2,
    Color? errorBg,
    Color? errorBorder,
    Color? statusOk,
    Color? statusWarn,
  }) {
    return RuolanColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceVariant2: surfaceVariant2 ?? this.surfaceVariant2,
      chipBg: chipBg ?? this.chipBg,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      primary: primary ?? this.primary,
      primaryFg: primaryFg ?? this.primaryFg,
      onSurfaceStrong: onSurfaceStrong ?? this.onSurfaceStrong,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      border: border ?? this.border,
      blockquote: blockquote ?? this.blockquote,
      codeBg: codeBg ?? this.codeBg,
      accentWarm: accentWarm ?? this.accentWarm,
      avatarUser: avatarUser ?? this.avatarUser,
      avatarAssistant: avatarAssistant ?? this.avatarAssistant,
      errorText: errorText ?? this.errorText,
      errorText2: errorText2 ?? this.errorText2,
      errorBg: errorBg ?? this.errorBg,
      errorBorder: errorBorder ?? this.errorBorder,
      statusOk: statusOk ?? this.statusOk,
      statusWarn: statusWarn ?? this.statusWarn,
    );
  }

  @override
  ThemeExtension<RuolanColors> lerp(ThemeExtension<RuolanColors>? other, double t) {
    if (other is! RuolanColors) return this;
    return RuolanColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceVariant2: Color.lerp(surfaceVariant2, other.surfaceVariant2, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryFg: Color.lerp(primaryFg, other.primaryFg, t)!,
      onSurfaceStrong: Color.lerp(onSurfaceStrong, other.onSurfaceStrong, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      blockquote: Color.lerp(blockquote, other.blockquote, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      accentWarm: Color.lerp(accentWarm, other.accentWarm, t)!,
      avatarUser: Color.lerp(avatarUser, other.avatarUser, t)!,
      avatarAssistant: Color.lerp(avatarAssistant, other.avatarAssistant, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorText2: Color.lerp(errorText2, other.errorText2, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      statusWarn: Color.lerp(statusWarn, other.statusWarn, t)!,
    );
  }
}
