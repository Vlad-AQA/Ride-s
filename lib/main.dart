import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'i18n.dart';
import 'map_screen.dart';
import 'repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLanguage(PlatformDispatcher.instance.locale.languageCode);

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const App(home: _NoServer()));
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(App(home: MapScreen(repo: Repo())));
}

class App extends StatelessWidget {
  const App({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: lang,
      builder: (context, _, _) => MaterialApp(
        title: 'ThaiRide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E6BFF),
            brightness: Brightness.dark,
            primary: const Color(0xFF1E6BFF),
            onPrimary: Colors.white,
            surface: const Color(0xFF16181D),
          ),
          scaffoldBackgroundColor: const Color(0xFF101114),
        ),
        home: home,
      ),
    );
  }
}

class _NoServer extends StatelessWidget {
  const _NoServer();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(tr('no_server'), textAlign: TextAlign.center),
          ),
        ),
      );
}
