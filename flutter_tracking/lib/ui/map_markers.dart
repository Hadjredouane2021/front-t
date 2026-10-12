import 'package:flutter/material.dart';

import '../core/status.dart';
import '../core/theme.dart';

// Géométrie commune : la pointe de l'épingle est au CENTRE de la boîte du
// marqueur (flutter_map centre la boîte sur la coordonnée). Tout le dessin
// occupe donc la moitié haute.

/// Épingle constatateur : pastille ronde (initiales) + pointe + étiquette nom.
class AgentMarker extends StatefulWidget {
  const AgentMarker({
    super.key,
    required this.color,
    required this.name,
    required this.hasPosition,
    required this.offline,
    required this.selected,
    required this.phase,
  });

  final Color color;
  final String name;
  final bool hasPosition;
  final bool offline;
  final bool selected;

  /// Décalage 0..1 pour désynchroniser les pulsations entre agents.
  final double phase;

  static const size = Size(170, 160);

  @override
  State<AgentMarker> createState() => _AgentMarkerState();
}

class _AgentMarkerState extends State<AgentMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  bool get _animated => widget.hasPosition && !widget.offline;

  @override
  void initState() {
    super.initState();
    _c.value = widget.phase;
    if (_animated) _c.repeat();
  }

  @override
  void didUpdateWidget(AgentMarker old) {
    super.didUpdateWidget(old);
    if (_animated && !_c.isAnimating) _c.repeat();
    if (!_animated && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = AgentMarker.size.height / 2;
    final selected = widget.selected;
    final muted = !widget.hasPosition || widget.offline;
    final fill = muted ? Color.lerp(widget.color, const Color(0xFF9E9E98), 0.55)! : widget.color;
    final pin = selected ? 52.0 : 42.0;
    const tail = 9.0;

    return SizedBox.fromSize(
      size: AgentMarker.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Ombre au sol + pulsation à l'emplacement exact.
          Positioned(
            top: half - 12,
            child: SizedBox(
              width: 60,
              height: 24,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) =>
                    CustomPaint(painter: _GroundPainter(selected ? AppColors.yellow : fill, _animated ? _c.value : -1)),
              ),
            ),
          ),
          // Pointe.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: half - tail - 1,
            child: CustomPaint(
              size: const Size(18, tail + 1),
              painter: _TailPainter(selected ? AppColors.yellow : Colors.white),
            ),
          ),
          // Pastille.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            top: half - tail - pin + 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: pin,
              height: pin,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.yellow : Colors.white,
                boxShadow: AppShadows.floating,
              ),
              padding: EdgeInsets.all(selected ? 5 : 3.5),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
                alignment: Alignment.center,
                child: widget.offline
                    ? const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 17)
                    : Text(
                        initials(widget.name),
                        style: TextStyle(
                          color: AppColors.onColor(fill),
                          fontWeight: FontWeight.w900,
                          fontSize: selected ? 15 : 13,
                        ),
                      ),
              ),
            ),
          ),
          // Badge statut hors ligne.
          if (widget.offline)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              top: half - tail - pin - 2,
              left: AgentMarker.size.width / 2 + pin / 2 - 14,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.offline,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.priority_high_rounded, size: 11, color: Colors.white),
              ),
            ),
          // Étiquette nom.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: half - tail - pin - 30,
            child: Container(
              constraints: BoxConstraints(maxWidth: AgentMarker.size.width),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.text : Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadows.card,
              ),
              child: Text(
                _firstName(widget.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _firstName(String raw) {
    final s = shortAgentName(raw).toLowerCase();
    return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(size.width / 2 + 2, size.height * 0.7, size.width / 2, size.height)
      ..quadraticBezierTo(size.width / 2 - 2, size.height * 0.7, 0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

class _GroundPainter extends CustomPainter {
  _GroundPainter(this.color, this.t);
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (t >= 0) {
      final w = 14 + 44 * t;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: w * 0.4),
        Paint()..color = color.withValues(alpha: 0.45 * (1 - t)),
      );
    }
    canvas.drawOval(Rect.fromCenter(center: c, width: 16, height: 6), Paint()..color = const Color(0x40000000));
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.t != t || old.color != color;
}

/// Épingle "Lieu d'accident" pour le résultat de géocodage.
class AccidentMarker extends StatefulWidget {
  const AccidentMarker({super.key});

  static const size = Size(180, 190);

  @override
  State<AccidentMarker> createState() => _AccidentMarkerState();
}

class _AccidentMarkerState extends State<AccidentMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = AccidentMarker.size.height / 2;
    const pin = 58.0;
    const tail = 12.0;
    return SizedBox.fromSize(
      size: AccidentMarker.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: half - 14,
            child: SizedBox(
              width: 80,
              height: 28,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(painter: _GroundPainter(AppColors.danger, _c.value)),
              ),
            ),
          ),
          Positioned(
            top: half - tail - 1,
            child: const CustomPaint(size: Size(22, tail + 1), painter: _TailPainter(AppColors.danger)),
          ),
          Positioned(
            top: half - tail - pin + 1,
            child: Container(
              width: pin,
              height: pin,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: AppShadows.floating,
              ),
              child: const Icon(Icons.car_crash_rounded, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            top: half - tail - pin - 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.text,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadows.card,
              ),
              child: const Text(
                "Lieu d'accident",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase stable par agent (hash uid), comme le décalage d'animation CSS Angular.
double markerPhase(String uid) => (AppColors.hashUid('$uid:phase') % 100) / 100;
