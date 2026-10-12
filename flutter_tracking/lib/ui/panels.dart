import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/status.dart';
import '../core/theme.dart';
import '../data/geocoding_service.dart';
import '../models/constatateur.dart';
import '../state/tracking_controller.dart';
import 'widgets/common.dart';

// ---------------------------------------------------------------------------
// Pastille de connexion temps réel
// ---------------------------------------------------------------------------

class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key, required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.green : AppColors.offline;
    return AppCard(
      radius: 999,
      color: connected ? AppColors.card : const Color(0xFFFFEBEC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: color, size: 8, animate: connected),
          const SizedBox(width: 8),
          Text(
            connected ? 'En direct' : 'Hors ligne',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: connected ? AppColors.text : color),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadii.md,
      color: const Color(0xFFFFEBEC),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_rounded, color: AppColors.offline, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8F1D22), fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8F1D22)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recherche d'adresse (Nominatim)
// ---------------------------------------------------------------------------

class AddressSearchBar extends StatefulWidget {
  const AddressSearchBar({super.key, required this.controller, this.compact = false});
  final TrackingController controller;
  final bool compact;

  @override
  State<AddressSearchBar> createState() => _AddressSearchBarState();
}

class _AddressSearchBarState extends State<AddressSearchBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.controller.searchAddress(_text.text);
      if (!mounted) return;
      _focus.unfocus();
      setState(() => _busy = false);
      await showDistanceSheet(context, widget.controller, outcome);
    } on GeocodeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = widget.controller.geocodePin != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard(
          radius: 999,
          shadow: AppShadows.floating,
          padding: const EdgeInsets.fromLTRB(18, 5, 5, 5),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  onSubmitted: (_) => _search(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  cursorColor: AppColors.green,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "Où est l'accident ?",
                    hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (hasPin)
                IconButton(
                  tooltip: 'Retirer le marqueur',
                  onPressed: () {
                    widget.controller.clearGeocodePin();
                    _text.clear();
                  },
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                ),
              const SizedBox(width: 4),
              YellowButton(
                onPressed: _busy ? null : _search,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.text),
                      )
                    : widget.compact
                    ? const Icon(Icons.search_rounded)
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.search_rounded), SizedBox(width: 6), Text('Rechercher')],
                      ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ErrorBanner(message: _error!, onClose: () => setState(() => _error = null)),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Constatateurs proches d'une adresse
// ---------------------------------------------------------------------------

Future<void> showDistanceSheet(BuildContext context, TrackingController controller, SearchOutcome outcome) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => _DistanceSheet(controller: controller, outcome: outcome),
  );
}

class _DistanceSheet extends StatelessWidget {
  const _DistanceSheet({required this.controller, required this.outcome});
  final TrackingController controller;
  final SearchOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final items = outcome.distances;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(9)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 4),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                    child: const Icon(Icons.near_me_rounded, color: AppColors.text, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les plus proches',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        Text(
                          'Touchez un constatateur pour le localiser',
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        outcome.result.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _DistanceRow(
                  rank: i + 1,
                  item: items[i],
                  onTap: () {
                    controller.select(items[i].agent.uid);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceRow extends StatelessWidget {
  const _DistanceRow({required this.rank, required this.item, required this.onTap});
  final int rank;
  final AgentDistance item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final best = rank == 1;
    final color = AppColors.agent(item.agent.uid);
    return Material(
      color: best ? AppColors.yellowSoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: best ? AppColors.yellow : AppColors.border, width: best ? 2 : 1),
          ),
          child: Row(
            children: [
              AgentAvatar(name: item.agent.infos.nom, color: color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (best) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(999)),
                            child: const Text(
                              'Le + proche',
                              style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            item.agent.infos.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    StatusPill(item.status, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: best ? AppColors.green : AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatDistance(item.meters),
                  style: mono(14, color: best ? Colors.white : AppColors.green, weight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fiche de l'agent sélectionné
// ---------------------------------------------------------------------------

class AgentDetailCard extends StatelessWidget {
  const AgentDetailCard({super.key, required this.controller, required this.agent});
  final TrackingController controller;
  final Constatateur agent;

  static final _date = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final p = agent.position;
    final status = controller.statusOf(agent);
    final color = AppColors.agent(agent.uid);
    final battery = p?.niveauBatterie;
    return AppCard(
      radius: AppRadii.xl,
      shadow: AppShadows.floating,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AgentAvatar(name: agent.infos.nom, color: color, size: 56, statusColor: AppColors.tone(status.tone)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.infos.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 5),
                    StatusPill(status, dense: true),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Fermer',
                size: 38,
                background: AppColors.surface,
                onPressed: () => controller.select(null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                icon: Icons.battery_charging_full_rounded,
                label: 'Batterie',
                value: battery == null ? 'N/A' : '$battery%',
                color: battery == null
                    ? AppColors.textFaint
                    : battery < 15
                    ? AppColors.offline
                    : battery < 35
                    ? AppColors.mission
                    : AppColors.green,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.speed_rounded,
                label: 'Vitesse',
                value: p == null ? 'N/A' : '${p.vitesseKmh.toStringAsFixed(1)} km/h',
                color: AppColors.text,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: p?.modeTracking == ModeTracking.enMouvement ? Icons.directions_car_rounded : Icons.place_rounded,
                label: 'Mode',
                value: p == null ? '—' : (p.modeTracking == ModeTracking.enMouvement ? 'En route' : 'À l\'arrêt'),
                color: AppColors.mission,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: status.stale ? AppColors.offline : AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p == null
                      ? 'Aucune position reçue'
                      : 'Vu le ${_date.format(DateTime.fromMillisecondsSinceEpoch(p.timestamp))} · ${relativeAge(p.timestamp, controller.now)}',
                  style: mono(12.5, color: status.stale ? AppColors.offline : AppColors.textMuted),
                ),
              ),
              if (p != null && p.precision > 0)
                Text('±${p.precision.round()} m', style: mono(12.5, color: AppColors.textFaint)),
            ],
          ),
          if (agent.infos.telephone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(agent.infos.telephone, style: mono(12.5)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          YellowButton(
            expand: true,
            onPressed: () => controller.openHistory(agent.uid),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.route_rounded), SizedBox(width: 8), Text('Voir le trajet')],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Historique des positions
// ---------------------------------------------------------------------------

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key, required this.controller});
  final TrackingController controller;

  static final _time = DateFormat('HH:mm', 'fr_FR');
  static final _day = DateFormat('dd/MM', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final agent = c.historyAgent;
    final color = c.historyFor == null ? AppColors.green : AppColors.agent(c.historyFor!);
    final entries = c.history.reversed.toList();

    return AppCard(
      radius: AppRadii.xl,
      shadow: AppShadows.floating,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
            child: Row(
              children: [
                if (agent != null)
                  AgentAvatar(name: agent.infos.nom, color: color, size: 42)
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trajet récent', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text(
                        [
                          if (agent != null) agent.infos.nom,
                          if (c.history.isNotEmpty) '${c.history.length} points',
                        ].join(' · '),
                        style: mono(12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Fermer',
                  size: 38,
                  background: AppColors.surface,
                  onPressed: c.closeHistory,
                ),
              ],
            ),
          ),
          if (c.historyLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))),
            )
          else if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'Aucune position historique disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
            )
          else
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final focused = identical(e, c.focusedEntry);
                  final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
                  return Material(
                    color: focused ? AppColors.yellow : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: InkWell(
                      onTap: () => c.focusEntry(focused ? null : e),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: SizedBox(
                        width: 118,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _time.format(dt),
                                    style: mono(16, color: AppColors.text, weight: FontWeight.w900),
                                  ),
                                  const Spacer(),
                                  if (i == 0)
                                    const Icon(Icons.flag_rounded, size: 16, color: AppColors.green)
                                  else
                                    Text(_day.format(dt), style: mono(11, color: AppColors.textMuted)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    e.modeTracking == ModeTracking.enMouvement
                                        ? Icons.directions_car_rounded
                                        : Icons.place_rounded,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text('${e.vitesseKmh.toStringAsFixed(0)} km/h', style: mono(11.5)),
                                  const Spacer(),
                                  Text('${e.niveauBatterie}%', style: mono(11.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
