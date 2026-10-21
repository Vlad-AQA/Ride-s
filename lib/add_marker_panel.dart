import 'package:flutter/material.dart';

import 'i18n.dart';
import 'models.dart';
import 'repo.dart';

/// Нижняя панель «Поставить метку»: адрес, комментарий, тип, кнопка.
class AddMarkerPanel extends StatefulWidget {
  const AddMarkerPanel({
    super.key,
    required this.address,
    required this.onCancel,
    required this.onSubmit,
  });

  final String? address;
  final VoidCallback onCancel;
  final Future<void> Function(MarkerType type, String comment) onSubmit;

  @override
  State<AddMarkerPanel> createState() => _AddMarkerPanelState();
}

class _AddMarkerPanelState extends State<AddMarkerPanel> {
  final _comment = TextEditingController();
  MarkerType _type = MarkerType.checkpoint;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_type, _comment.text);
    } on ServerError catch (e) {
      _show(errorText(e.message));
    } catch (_) {
      _show(tr('err_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.address ?? '…',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _comment,
                    maxLength: 280,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: tr('comment_hint'),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                    children: [
                      for (final t in MarkerType.values)
                        _TypeButton(
                          type: t,
                          selected: t == _type,
                          onTap: () => setState(() => _type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: scheme.primary),
                          ),
                          onPressed: _busy ? null : widget.onCancel,
                          child: const Icon(Icons.arrow_back),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(tr('add_marker')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.selected, required this.onTap});

  final MarkerType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : Colors.white70;
    return Material(
      color: selected ? scheme.primary : const Color(0xFF23262D),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(
                typeName(type),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 11, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
