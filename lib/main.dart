import 'package:aplikasi_photobooth_flutter/pages/main_menu.dart';
import 'package:aplikasi_photobooth_flutter/providers/settings.dart';
import 'package:aplikasi_photobooth_flutter/providers/start_event.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/events.dart';
import 'providers/layouts.dart';
import 'providers/sesi_foto.dart';
import 'providers/layout_editor_listenable.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Main global providers
        ChangeNotifierProvider<LayoutsProvider>(
          create: (_) => LayoutsProvider(),
        ),

        // Optional: Global state that's shared across the app
        Provider<SelectedElementNotifier>(
          create: (_) => SelectedElementNotifier(),
          dispose: (_, notifier) => notifier.dispose(),
        ),

        Provider<ZoomLevelNotifier>(
          create: (_) => ZoomLevelNotifier(),
          dispose: (_, notifier) => notifier.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => StartEventProvider()),
        ChangeNotifierProvider(create: (_) => SesiFotoProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Photobooth',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainMenu(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
