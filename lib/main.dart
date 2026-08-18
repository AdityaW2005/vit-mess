import 'package:flutter/material.dart';

import 'app.dart';
import 'core/service_locator.dart';

/// Entry point.
///
/// Dependencies are wired and persisted settings are read before the first
/// frame, so the app never flashes the wrong screen on launch.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MessUpApp());
}
