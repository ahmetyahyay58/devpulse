import 'package:flutter/material.dart';

import 'api/health_api.dart';
import 'config.dart';
import 'screens/health_screen.dart';

void main() {
  runApp(DevPulseApp(api: HealthApi(baseUrl: apiBaseUrl)));
}

class DevPulseApp extends StatelessWidget {
  const DevPulseApp({super.key, required this.api});

  final HealthApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevPulse',
      debugShowCheckedModeBanner: false,
      // Yalnızca koyu tema; renkler tek bir "tohum" renkten türetilir.
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: HealthScreen(api: api),
    );
  }
}
