import 'package:flutter/material.dart';

import '../../core/status.dart';
import '../../core/theme.dart';

/// Carte blanche arrondie avec ombre douce.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.radius = AppRadii.lg,
    this.padding = EdgeInsets.zero,
    this.color = AppColors.card,
    this.shadow = AppShadows.card,
    this.border,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color color;
  final List<BoxShadow>? shadow;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        border: border,
      ),
      child: child,
    );
  }
}

/// Pastille de statut : fond teinté, point coloré, libellé lisible.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.dense = false, this.tooltip});

  final EffectiveStatus status;
  final bool dense;
  final String? tooltip;

  static String pretty(String label) => label.isEmpty ? label : label[0] + label.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.tone(status.tone);
    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: c, size: dense ? 6 : 7, animate: status.tone == StatusTone.available),
          SizedBox(width: dense ? 5 : 6),
          Text(
            pretty(status.label),
            style: TextStyle(
              color: AppColors.toneText(status.tone),
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}

/// Point coloré, optionnellement "respirant".
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8, this.animate = true});

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _PulsePainter(widget.color, widget.animate ? _c.value : 0)),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.color, this.t);
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    if (t > 0) {
      canvas.drawCircle(center, r + r * 1.6 * t, Paint()..color = color.withValues(alpha: 0.4 * (1 - t)));
    }
    canvas.drawCircle(center, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.color != color;
}

/// Bouton rond blanc flottant (contrôles carte, menu…).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.background = AppColors.card,
    this.foreground = AppColors.text,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.soft),
          child: Icon(icon, size: size * 0.48, color: foreground),
        ),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.card),
      child: tooltip == null ? button : Tooltip(message: tooltip, child: button),
    );
  }
}

/// Gros bouton pilule jaune à texte noir (CTA principal).
class YellowButton extends StatelessWidget {
  const YellowButton({super.key, required this.onPressed, required this.child, this.expand = false});

  final VoidCallback? onPressed;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? AppColors.yellow.withValues(alpha: 0.6) : AppColors.yellow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14),
            child: IconTheme.merge(
              data: const IconThemeData(color: AppColors.text, size: 18),
              child: expand ? Center(child: child) : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar rond à initiales sur la couleur de l'agent, avec pastille de statut.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, required this.name, required this.color, this.size = 44, this.statusColor});

  final String name;
  final Color color;
  final double size;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.22)),
            alignment: Alignment.center,
            child: Container(
              width: size * 0.78,
              height: size * 0.78,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              alignment: Alignment.center,
              child: Text(
                initials(name),
                style: TextStyle(color: AppColors.onColor(color), fontWeight: FontWeight.w900, fontSize: size * 0.3),
              ),
            ),
          ),
          if (statusColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
