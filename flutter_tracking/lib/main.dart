import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/theme.dart';
import 'state/tracking_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  runApp(const TrackingApp());
}

class TrackingApp extends StatefulWidget {
  const TrackingApp({super.key});

  @override
  State<TrackingApp> createState() => _TrackingAppState();
}

class _TrackingAppState extends State<TrackingApp> {
  final _controller = TrackingController()..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewAssist · Live Tracking',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(controller: _controller),
    );
  }
}
