import 'package:flutter/material.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:photobooth/providers/layout_editor_provider.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:photobooth/providers/sesi_foto.dart';
import 'package:photobooth/providers/settings_provider.dart';
import 'package:photobooth/screens/main_screen.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LayoutsProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => LayoutEditorProvider()),
        ChangeNotifierProvider(create: (_) => SesiFotoProvider()),
        ChangeNotifierProvider(create: (_) => PresetProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Photobooth',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.lightBlue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
