import 'package:flutter/material.dart';

import 'app.dart';
import 'platform/sqflite_platform.dart'
    if (dart.library.io) 'platform/sqflite_platform_io.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initSqfliteForDesktop();
  await AppState.instance.init();
  runApp(const EscritaDeLibrasApp());
}
