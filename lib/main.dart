import 'package:aplikasi_photobooth_flutter/pages/main_menu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/events.dart';
import 'providers/layouts.dart';
import 'providers/sesi_foto.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => LayoutsProvider()),
        ChangeNotifierProvider(create: (_) => SesiFotoProvider()),
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const MainMenu(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
