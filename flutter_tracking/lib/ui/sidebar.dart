import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/status.dart';
import '../core/theme.dart';
import '../models/constatateur.dart';
import '../state/tracking_controller.dart';
import 'widgets/common.dart';

/// Panneau latéral (desktop) : en-tête jaune, catégories, liste.
class AgentPanel extends StatelessWidget {
  const AgentPanel({super.key, required this.controller, this.onClose});

  final TrackingController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppCard(
      radius: AppRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _YellowHeader(controller: c, onClose: onClose),
          const SizedBox(height: 16),
          CategoryBubbles(controller: c),
          const SizedBox(height: 8),
          _ListTitle(controller: c),
          Expanded(child: _AgentListView(controller: c)),
          const _Footer(),
        ],
      ),
    );
  }
}

/// Contenu de la feuille glissante (mobile).
class AgentSheetContent extends StatelessWidget {
  const AgentSheetContent({super.key, required this.controller, required this.scrollController});

  final TrackingController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final visible = c.visibleAgents;
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(9)),
                ),
              ),
              CategoryBubbles(controller: c),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: NameSearchField(value: c.query, onChanged: c.setQuery),
              ),
              _ListTitle(controller: c),
            ],
          ),
        ),
        if (!c.loaded)
          const SliverToBoxAdapter(child: _ListSkeleton())
        else if (visible.isEmpty)
          SliverToBoxAdapter(child: _EmptyState(filtered: c.agents.isNotEmpty))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(c, visible[i]),
            ),
          ),
      ],
    );
  }
}

Widget _card(TrackingController c, Constatateur a) => AgentCard(
  key: ValueKey(a.uid),
  agent: a,
  status: c.statusOf(a),
  now: c.now,
  selected: c.selectedId == a.uid,
  onTap: () => c.select(a.uid),
  onHistory: () => c.openHistory(a.uid),
);

class _AgentListView extends StatelessWidget {
  const _AgentListView({required this.controller});
  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final visible = c.visibleAgents;
    if (!c.loaded) return const SingleChildScrollView(child: _ListSkeleton());
    if (visible.isEmpty) return _EmptyState(filtered: c.agents.isNotEmpty);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _card(c, visible[i]),
    );
  }
}

class _YellowHeader extends StatelessWidget {
  const _YellowHeader({required this.controller, this.onClose});
  final TrackingController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 20),
      decoration: const BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Image.asset('assets/images/newassist-logo.png', fit: BoxFit.contain),
              ),
              const Spacer(),
              if (onClose != null)
                RoundIconButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: onClose,
                  tooltip: 'Masquer le menu',
                  size: 38,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Où sont vos\nconstatateurs ?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.4),
          ),
          const SizedBox(height: 14),
          NameSearchField(value: controller.query, onChanged: controller.setQuery, onYellow: true),
        ],
      ),
    );
  }
}

/// Rangée de bulles rondes façon "catégories" : servent de filtres de statut.
class CategoryBubbles extends StatelessWidget {
  const CategoryBubbles({super.key, required this.controller});
  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final counts = controller.toneCounts;
    final items = <(StatusFilter, String, IconData, Color, int)>[
      (StatusFilter.all, 'Tous', Icons.groups_rounded, AppColors.text, controller.agents.length),
      (StatusFilter.available, 'Disponibles', Icons.check_rounded, AppColors.available, counts[StatusTone.available]!),
      (
        StatusFilter.mission,
        'En mission',
        Icons.directions_car_rounded,
        AppColors.mission,
        counts[StatusTone.mission]!,
      ),
      (
        StatusFilter.unavailable,
        'Indispo.',
        Icons.pause_rounded,
        AppColors.unavailable,
        counts[StatusTone.unavailable]!,
      ),
      (StatusFilter.offline, 'Hors ligne', Icons.wifi_off_rounded, AppColors.offline, counts[StatusTone.offline]!),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final (filter, label, icon, color, count) = items[i];
          return _Bubble(
            label: label,
            icon: icon,
            color: color,
            count: count,
            active: controller.filter == filter,
            onTap: () => controller.setFilter(filter),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.yellow : color.withValues(alpha: 0.12),
                    boxShadow: active ? AppShadows.card : null,
                  ),
                  child: Icon(icon, color: active ? AppColors.text : color, size: 26),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w900 : FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({required this.controller});
  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Constatateurs', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${controller.visibleAgents.length} sur ${controller.agents.length}',
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class NameSearchField extends StatefulWidget {
  const NameSearchField({super.key, required this.value, required this.onChanged, this.onYellow = false});
  final String value;
  final ValueChanged<String> onChanged;
  final bool onYellow;

  @override
  State<NameSearchField> createState() => _NameSearchFieldState();
}

class _NameSearchFieldState extends State<NameSearchField> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none);
    return TextField(
      controller: _ctrl,
      onChanged: (v) {
        widget.onChanged(v);
        setState(() {});
      },
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      cursorColor: AppColors.green,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rechercher un constatateur',
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.text),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: widget.onYellow ? Colors.white : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
      ),
    );
  }
}

class AgentCard extends StatefulWidget {
  const AgentCard({
    super.key,
    required this.agent,
    required this.status,
    required this.now,
    required this.selected,
    required this.onTap,
    required this.onHistory,
  });

  final Constatateur agent;
  final EffectiveStatus status;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHistory;

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _hover = false;
  static final _date = DateFormat('dd/MM HH:mm', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    final p = a.position;
    final color = AppColors.agent(a.uid);
    final selected = widget.selected;
    final age = relativeAge(p?.timestamp, widget.now);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover && !selected ? -2 : 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.yellowSoft : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: selected ? AppColors.yellow : AppColors.border, width: selected ? 2 : 1),
            boxShadow: _hover || selected ? AppShadows.card : AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AgentAvatar(
                    name: a.infos.nom,
                    color: color,
                    size: 48,
                    statusColor: AppColors.tone(widget.status.tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.infos.nom.isEmpty ? 'Sans nom' : a.infos.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(
                          widget.status,
                          dense: true,
                          tooltip: widget.status.stale
                              ? 'Statut déclaré : ${statusLabel(a.infos.statut)} — dernière position $age'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(
                    icon: p == null
                        ? Icons.location_disabled_rounded
                        : p.modeTracking == ModeTracking.enMouvement
                        ? Icons.directions_car_filled_rounded
                        : Icons.place_rounded,
                    label: p == null
                        ? 'Position inconnue'
                        : p.modeTracking == ModeTracking.enMouvement
                        ? 'En mouvement'
                        : 'Stationnaire',
                  ),
                  _Chip(
                    icon: _batteryIcon(p?.niveauBatterie),
                    label: p == null ? 'N/A' : '${p.niveauBatterie}%',
                    color: _batteryColor(p?.niveauBatterie),
                  ),
                  _Chip(icon: Icons.speed_rounded, label: '${(p?.vitesseKmh ?? 0).toStringAsFixed(1)} km/h'),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: widget.status.stale ? AppColors.offline : AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Tooltip(
                      message: p == null ? 'Aucune position reçue' : age,
                      child: Text(
                        p == null
                            ? 'Jamais vu'
                            : '${_date.format(DateTime.fromMillisecondsSinceEpoch(p.timestamp))} · $age',
                        style: mono(12, color: widget.status.stale ? AppColors.offline : AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onHistory,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    icon: const Icon(Icons.route_rounded, size: 16),
                    label: const Text('Historique'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _batteryIcon(int? level) {
    if (level == null) return Icons.battery_unknown_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 35) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  static Color? _batteryColor(int? level) {
    if (level == null) return null;
    if (level < 15) return AppColors.offline;
    if (level < 35) return AppColors.mission;
    return null;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.text),
          const SizedBox(width: 4),
          Text(
            label,
            style: mono(12, color: color ?? AppColors.text, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();

  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                height: 132,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  gradient: LinearGradient(
                    begin: Alignment(-2 + 2 * _c.value, 0),
                    end: Alignment(2 * _c.value, 0),
                    colors: const [Color(0xFFF0F0EC), Color(0xFFFAFAF8), Color(0xFFF0F0EC)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.yellowSoft, shape: BoxShape.circle),
            child: Icon(
              filtered ? Icons.filter_alt_off_rounded : Icons.person_search_rounded,
              size: 34,
              color: AppColors.mission,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'Aucun constatateur ne correspond.' : 'Aucun constatateur enregistré.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Newassist © Version 1',
        textAlign: TextAlign.center,
        style: mono(11.5, color: AppColors.textFaint),
      ),
    );
  }
}
