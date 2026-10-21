import 'package:flutter/material.dart';

import 'i18n.dart';
import 'models.dart';
import 'repo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo});

  final Repo repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        children: [
          _Header(tr('language')),
          ValueListenableBuilder(
            valueListenable: lang,
            builder: (context, current, _) => RadioGroup<String>(
              groupValue: current,
              onChanged: (code) => setLanguage(code!),
              child: Column(
                children: [
                  for (final e in languages.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value)),
                ],
              ),
            ),
          ),
          _Header(tr('show_types')),
          ValueListenableBuilder(
            valueListenable: repo.visibleTypes,
            builder: (context, visible, _) => Column(
              children: [
                for (final t in MarkerType.values)
                  SwitchListTile(
                    secondary: Icon(t.icon),
                    title: Text(typeName(t)),
                    value: visible.contains(t),
                    onChanged: (v) => repo.setTypeVisible(t, v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
        ),
      );
}
