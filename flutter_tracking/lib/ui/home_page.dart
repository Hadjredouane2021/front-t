import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/tracking_controller.dart';
import 'map_view.dart';
import 'panels.dart';
import 'sidebar.dart';
import 'widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final TrackingController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _mapKey = GlobalKey<TrackingMapState>();

  static const _wideBreakpoint = 960.0;
  static const _panelWidth = 392.0;
  static const _gap = 14.0;

  /// Hauteur initiale de la feuille glissante (mobile), en fraction d'écran.
  static const _sheetInitial = 0.42;
  static const _sheetMin = 0.2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          return ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => wide ? _wideLayout() : _mobileLayout(constraints),
          );
        },
      ),
    );
  }

  Widget? _bottomPanel() {
    final c = widget.controller;
    final selected = c.selected;
    if (c.showHistory) return HistoryPanel(key: const ValueKey('history'), controller: c);
    if (selected != null) {
      return AgentDetailCard(key: ValueKey('agent-${selected.uid}'), controller: c, agent: selected);
    }
    return null;
  }

  // --- Desktop ----------------------------------------------------------------

  Widget _wideLayout() {
    final c = widget.controller;
    final panel = _bottomPanel();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(_gap),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: c.sidebarOpen ? _panelWidth + _gap : 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: _panelWidth,
                  maxWidth: _panelWidth,
                  child: AgentPanel(controller: c, onClose: c.toggleSidebar),
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TrackingMap(
                        key: _mapKey,
                        controller: c,
                        overlayPadding: EdgeInsets.fromLTRB(0, 80, 60, panel == null ? 0 : (c.showHistory ? 170 : 330)),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      left: 18,
                      right: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!c.sidebarOpen) ...[
                            RoundIconButton(
                              icon: Icons.menu_rounded,
                              tooltip: 'Afficher les constatateurs',
                              size: 52,
                              onPressed: c.toggleSidebar,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 620),
                                child: AddressSearchBar(controller: c),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ConnectionPill(connected: c.connected),
                          ),
                        ],
                      ),
                    ),
                    if (c.error != null)
                      Positioned(
                        top: 90,
                        left: 18,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: ErrorBanner(message: c.error!, onClose: c.dismissError),
                        ),
                      ),
                    Positioned(
                      right: 18,
                      top: 0,
                      bottom: 0,
                      child: Center(child: MapControls(mapKey: _mapKey)),
                    ),
                    Positioned(
                      left: 18,
                      right: 90,
                      bottom: 18,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: c.showHistory ? 920 : 460),
                          child: _slideSwitcher(panel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Mobile -----------------------------------------------------------------

  Widget _mobileLayout(BoxConstraints constraints) {
    final c = widget.controller;
    final panel = _bottomPanel();
    final sheetVisible = panel == null;
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: TrackingMap(
            key: _mapKey,
            controller: c,
            overlayPadding: EdgeInsets.fromLTRB(
              0,
              90 + topInset,
              0,
              sheetVisible ? constraints.maxHeight * _sheetInitial : (c.showHistory ? 190 : 400),
            ),
          ),
        ),
        Positioned(
          top: topInset + 12,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AddressSearchBar(controller: c, compact: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  ConnectionPill(connected: c.connected),
                  const Spacer(),
                  MapControls(mapKey: _mapKey, compact: true),
                ],
              ),
              if (c.error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(message: c.error!, onClose: c.dismissError),
              ],
            ],
          ),
        ),
        if (sheetVisible)
          DraggableScrollableSheet(
            key: const ValueKey('agents-sheet'),
            initialChildSize: _sheetInitial,
            minChildSize: _sheetMin,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [_sheetMin, _sheetInitial, 0.92],
            builder: (context, scroll) => DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                boxShadow: AppShadows.floating,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                child: AgentSheetContent(controller: c, scrollController: scroll),
              ),
            ),
          ),
        Positioned(left: 10, right: 10, bottom: 10, child: SafeArea(top: false, child: _slideSwitcher(panel))),
      ],
    );
  }

  Widget _slideSwitcher(Widget? child) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
        child: child,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
