import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:enjoy/ui/enjoy_colors.dart';
import 'package:enjoy/ui/enjoy_theme.dart';
import 'package:enjoy/ui/widgets/enjoy_effects.dart';
import 'package:enjoy/ui/widgets/enjoy_image.dart';

// ===================================================================
//  EnjoyScaffold — fondo con degradado + halos de glow (equivale a body)
// ===================================================================
class EnjoyScaffold extends StatelessWidget {
  const EnjoyScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.padding = const EdgeInsets.fromLTRB(18, 4, 18, 0),
    this.showGlow = true,
    this.safeTop = true,
    this.safeBottom = true,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final EdgeInsets padding;
  final bool showGlow;
  final bool safeTop;
  final bool safeBottom;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomBar,
      // SizedBox.expand + StackFit.expand: el degradado cubre SIEMPRE toda la
      // pantalla, aunque el contenido sea corto (evita el "corte" negro abajo).
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: ec.bgGradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showGlow) ...[
                Positioned(
                  top: -120,
                  left: -80,
                  child: GlowHalo(size: 420, color: ec.glowOrange),
                ),
                Positioned(
                  top: -60,
                  right: -120,
                  child: GlowHalo(size: 380, color: ec.glowBlue),
                ),
              ],
              SafeArea(
                top: safeTop,
                bottom: safeBottom,
                child: Padding(padding: padding, child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
//  EnjoyAppBar — barra con chip de retroceso + título Sora (.appbar)
// ===================================================================
class EnjoyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EnjoyAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBack,
    this.onBack,
    this.leading,
  });

  final String? title;
  final List<Widget>? actions;
  final bool? showBack;
  final VoidCallback? onBack;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    // Muestra el chip de retroceso si: se fuerza (showBack), hay un onBack
    // explícito (navegación interna por pestañas, p.ej. panel admin) o hay
    // una ruta apilada que se puede cerrar.
    final canPop =
        showBack ?? (onBack != null || Navigator.of(context).canPop());
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (canPop)
              BackChip(onTap: onBack ?? () => Navigator.of(context).maybePop()),
            if ((leading != null || canPop) && title != null)
              const SizedBox(width: 12),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  style: EnjoyTheme.heading(size: 19, color: ec.text),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            ...?actions,
          ],
        ),
      ),
    );
  }
}

/// Chip cuadrado de retroceso (`.bk`).
class BackChip extends StatelessWidget {
  const BackChip({super.key, this.onTap, this.icon = Icons.chevron_left});
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return _Tappable(
      onTap: onTap,
      borderRadius: 13,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ec.stroke),
        ),
        child: Icon(icon, color: ec.text, size: 22),
      ),
    );
  }
}

/// Botón-ícono cuadrado glass para acciones del appbar.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.accent = false,
    this.size = 42,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return _Tappable(
      onTap: onTap,
      borderRadius: 13,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: accent ? ec.accentGradient : null,
          color: accent ? null : ec.glass,
          borderRadius: BorderRadius.circular(13),
          border: accent ? null : Border.all(color: ec.stroke),
        ),
        child: Icon(icon,
            color: accent ? ec.onAccent : (color ?? ec.textSoft), size: 20),
      ),
    );
  }
}

// ===================================================================
//  GlassCard — tarjeta esmerilada (.card / .glass)
// ===================================================================
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.accent = false,
    this.color,
    this.borderColor,
    this.borderStrong = false,
    this.onTap,
    this.blur = true,
    this.margin,
    this.leftAccent,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Usa el degradado naranja sutil de fondo (header destacado).
  final bool accent;
  final Color? color;
  final Color? borderColor;
  final bool borderStrong;
  final VoidCallback? onTap;
  final bool blur;
  final EdgeInsets? margin;

  /// Barra de acento vertical a la izquierda (estados de solicitudes).
  final Color? leftAccent;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final border = borderColor ?? (borderStrong ? ec.strokeStrong : ec.stroke);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: accent
            ? LinearGradient(
                colors: [ec.cardGradTop, ec.cardGradBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: accent ? null : (color ?? ec.glass),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent ? ec.orange.withValues(alpha: .28) : border,
        ),
      ),
      child: child,
    );

    if (leftAccent != null) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border(left: BorderSide(color: leftAccent!, width: 3)),
        ),
        child: content,
      );
    }

    if (blur && ec.isDark) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = _Tappable(onTap: onTap, borderRadius: radius, child: content);
    }

    return margin == null ? content : Padding(padding: margin!, child: content);
  }
}

// ===================================================================
//  EnjoyButton — botón con variantes (.btn)
// ===================================================================
enum EnjoyButtonVariant { orange, ghost, green, red, blueGlass }

class EnjoyButton extends StatelessWidget {
  const EnjoyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = EnjoyButtonVariant.orange,
    this.expand = true,
    this.dense = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final EnjoyButtonVariant variant;
  final bool expand;
  final bool dense;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final isOrange = variant == EnjoyButtonVariant.orange;
    final isGreen = variant == EnjoyButtonVariant.green;

    Color fg;
    Color? solid;
    Gradient? grad;
    Border? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case EnjoyButtonVariant.orange:
        grad = ec.accentGradient;
        fg = ec.onAccent;
        shadow = [
          BoxShadow(
            color: ec.orange.withValues(alpha: .45),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -8,
          ),
        ];
        break;
      case EnjoyButtonVariant.green:
        grad = ec.greenGradient;
        fg = ec.isDark ? const Color(0xFF06210F) : Colors.white;
        break;
      case EnjoyButtonVariant.ghost:
        solid = ec.glassStrong;
        fg = ec.text;
        border = Border.all(color: ec.strokeStrong);
        break;
      case EnjoyButtonVariant.red:
        solid = ec.red.withValues(alpha: .16);
        fg = ec.red;
        border = Border.all(color: ec.red.withValues(alpha: .4));
        break;
      case EnjoyButtonVariant.blueGlass:
        solid = ec.blue.withValues(alpha: .14);
        fg = ec.blue;
        border = Border.all(color: ec.blue.withValues(alpha: .3));
        break;
    }

    final radius = dense ? 13.0 : 17.0;
    final padV = dense ? 11.0 : 15.0;

    Widget inner = loading
        ? SizedBox(
            height: dense ? 16 : 20,
            width: dense ? 16 : 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 16 : 18, color: fg),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  style: EnjoyTheme.heading(
                      size: dense ? 13 : 15, weight: FontWeight.w600, color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 9),
                Icon(trailingIcon, size: dense ? 16 : 18, color: fg),
              ],
            ],
          );

    Widget body = Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: dense ? 16 : 18),
      decoration: BoxDecoration(
        gradient: grad,
        color: solid,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow,
      ),
      alignment: Alignment.center,
      child: inner,
    );

    // Brillo deslizante para el CTA naranja.
    if (isOrange && !loading) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(children: [body, const Positioned.fill(child: ShineSweep())]),
      );
    }
    if (isGreen) {
      // sin sombra extra
    }

    return _Tappable(
      onTap: loading ? null : onPressed,
      borderRadius: radius,
      child: body,
    );
  }
}

// ===================================================================
//  Pill — etiqueta redondeada (.pill)
// ===================================================================
enum PillVariant { orange, green, red, blue, glass }

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.variant = PillVariant.glass,
    this.icon,
    this.dot = false,
    this.dense = false,
    this.onTap,
  });

  final String label;
  final PillVariant variant;
  final IconData? icon;
  final bool dot;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    late Color bg, fg, br;
    switch (variant) {
      case PillVariant.orange:
        bg = ec.orange.withValues(alpha: .14);
        fg = ec.orangeSoft;
        br = ec.orange.withValues(alpha: .30);
        break;
      case PillVariant.green:
        bg = ec.green.withValues(alpha: .13);
        fg = ec.green;
        br = ec.green.withValues(alpha: .30);
        break;
      case PillVariant.red:
        bg = ec.red.withValues(alpha: .13);
        fg = ec.red;
        br = ec.red.withValues(alpha: .30);
        break;
      case PillVariant.blue:
        bg = ec.blue.withValues(alpha: .13);
        fg = ec.blue;
        br = ec.blue.withValues(alpha: .30);
        break;
      case PillVariant.glass:
        bg = ec.glassStrong;
        fg = ec.textSoft;
        br = ec.stroke;
        break;
    }

    final child = Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 9 : 13, vertical: dense ? 4 : 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: br),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            BlinkDot(color: fg),
            const SizedBox(width: 7),
          ] else if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: EnjoyTheme.body(
                size: dense ? 10.5 : 12, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
    return onTap == null
        ? child
        : _Tappable(onTap: onTap, borderRadius: 999, child: child);
  }
}

// ===================================================================
//  IconBox — caja de ícono (.ic-box)
// ===================================================================
class IconBox extends StatelessWidget {
  const IconBox(
    this.icon, {
    super.key,
    this.accent = false,
    this.size = 44,
    this.radius = 13,
    this.color,
    this.iconSize = 20,
  });

  final IconData icon;
  final bool accent;
  final double size;
  final double radius;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: accent ? ec.accentGradient : ec.iconGlassGradient,
        borderRadius: BorderRadius.circular(radius),
        border: accent ? null : Border.all(color: ec.stroke),
      ),
      child: Icon(icon,
          size: iconSize,
          color: accent ? ec.onAccent : (color ?? ec.orangeSoft)),
    );
  }
}

// ===================================================================
//  EnjoyAvatar — avatar con iniciales (.avatar)
// ===================================================================
class EnjoyAvatar extends StatelessWidget {
  const EnjoyAvatar(
    this.label, {
    super.key,
    this.size = 44,
    this.radius,
    this.imageUrl,
    this.accent = true,
  });

  final String label;
  final double size;
  final double? radius;
  final String? imageUrl;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final br = BorderRadius.circular(radius ?? size / 2);
    final initials = _initials(label);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: accent
            ? ec.accentGradient
            : LinearGradient(colors: [ec.iconGlassTop, ec.iconGlassBottom]),
        borderRadius: br,
        image: (imageUrl != null && imageUrl!.isNotEmpty)
            ? DecorationImage(
                image: enjoyImageProvider(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? null
          : Text(
              initials,
              style: EnjoyTheme.heading(
                size: size * 0.36,
                weight: FontWeight.w700,
                color: accent ? ec.onAccent : ec.orangeSoft,
              ),
            ),
    );
  }

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

// ===================================================================
//  EnjoyToggle — switch estilizado (.tg)
// ===================================================================
class EnjoyToggle extends StatelessWidget {
  const EnjoyToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(value: value, onChanged: onChanged);
  }
}

// ===================================================================
//  Steps — barra de pasos (.steps)
// ===================================================================
class Steps extends StatelessWidget {
  const Steps({super.key, required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      children: List.generate(count, (i) {
        final on = i < current;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            decoration: BoxDecoration(
              gradient: on ? ec.accentGradient : null,
              color: on ? null : ec.glassStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

// ===================================================================
//  StatCard — tarjeta de métrica (.stat)
// ===================================================================
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.accent = false,
    this.valueSize = 26,
  });
  final String value;
  final String label;
  final bool accent;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ec.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ec.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: EnjoyTheme.heading(
                  size: valueSize,
                  weight: FontWeight.w800,
                  color: accent ? ec.orangeSoft : ec.text)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: EnjoyTheme.body(
                  size: 11.5, weight: FontWeight.w600, color: ec.textMute)),
        ],
      ),
    );
  }
}

// ===================================================================
//  SectionTitle — título de sección + "ver todo" (.sectit / .seeall)
// ===================================================================
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: EnjoyTheme.heading(size: 16, color: ec.text)),
        if (trailing != null)
          _Tappable(
            onTap: onTrailing,
            borderRadius: 8,
            child: Text(trailing!,
                style: EnjoyTheme.body(
                    size: 13, weight: FontWeight.w600, color: ec.orangeSoft)),
          ),
      ],
    );
  }
}

/// Etiqueta uppercase pequeña (.label).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 9, top: 2),
      child: Text(
        text.toUpperCase(),
        style: EnjoyTheme.body(size: 11, weight: FontWeight.w700, color: ec.textMute)
            .copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

/// Línea divisoria sutil (.divider).
class EnjoyDivider extends StatelessWidget {
  const EnjoyDivider({super.key, this.height = 28});
  final double height;
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: (height - 1) / 2),
      color: ec.stroke,
    );
  }
}

/// Fila de lista glass (.list-row).
class ListRowTile extends StatelessWidget {
  const ListRowTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.borderColor,
    this.titleColor,
  });
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return _Tappable(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? ec.stroke),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 13)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: EnjoyTheme.heading(
                          size: 14, color: titleColor ?? ec.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

// ===================================================================
//  Helper interno de toque con feedback
// ===================================================================
class _Tappable extends StatelessWidget {
  const _Tappable({this.onTap, required this.child, this.borderRadius = 12});
  final VoidCallback? onTap;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
