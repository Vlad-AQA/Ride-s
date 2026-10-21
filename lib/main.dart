import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'i18n.dart';
import 'map_screen.dart';
import 'repo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Первый кадр рисуем сразу, всё остальное — в _Startup: если что-то упадёт,
  // пользователь увидит ошибку, а не вечную заставку.
  runApp(const App(home: _Startup()));
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

class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  static bool _supabaseReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await loadLanguage(PlatformDispatcher.instance.locale.languageCode);
    } catch (_) {
      // Без сохранённого языка обойдёмся: останется язык по умолчанию.
    }
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      setState(() => _error = tr('no_server'));
      return;
    }
    try {
      if (!_supabaseReady) {
        await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey)
            .timeout(const Duration(seconds: 20));
        _supabaseReady = true;
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${tr('err_generic')}\n\n$e');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MapScreen(repo: Repo())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(error, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _start, child: Text(tr('retry'))),
                  ],
                ),
        ),
      ),
    );
  }
}
