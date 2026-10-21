import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'i18n.dart';
import 'models.dart';
import 'repo.dart';

/// Карточка метки: тип, комментарии, подтверждения, адрес, голосование.
class MarkerSheet extends StatefulWidget {
  const MarkerSheet({super.key, required this.repo, required this.markerId});

  final Repo repo;
  final String markerId;

  @override
  State<MarkerSheet> createState() => _MarkerSheetState();
}

class _MarkerSheetState extends State<MarkerSheet> {
  final _input = TextEditingController();
  List<MarkerComment>? _comments;
  bool _busy = false;

  Repo get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await repo.comments(widget.markerId);
      if (mounted) setState(() => _comments = list);
    } catch (_) {
      if (mounted) setState(() => _comments = []);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success, bool close = false}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action();
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
      if (close) navigator.pop();
    } on ServerError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e.message))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('err_generic'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await repo.addComment(widget.markerId, text);
      _input.clear();
      await _loadComments();
    });
  }

  void _share(RoadMarker m) {
    final where = m.address ?? '';
    final link = 'https://maps.google.com/?q=${m.point.latitude},${m.point.longitude}';
    SharePlus.instance.share(ShareParams(
      text: '${tr('share_text', {'type': typeName(m.type), 'address': where})}\n$link',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: repo.markers,
      builder: (context, markers, _) {
        final m = markers[widget.markerId];
        if (m == null) {
          return SizedBox(
            height: 160,
            child: Center(child: Text(tr('err_marker_not_found'))),
          );
        }
        final status = m.confirmations > 0
            ? tr('confirmed', {'n': m.confirmations, 'ago': timeAgo(m.lastSeenAt)})
            : tr('not_confirmed', {'ago': timeAgo(m.createdAt)});
        final isMine = m.authorId == repo.userId;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: scheme.primary,
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Icon(m.type.icon, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          typeName(m.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('share'),
                        onPressed: () => _share(m),
                        icon: const Icon(Icons.ios_share, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: _commentsList(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLength: 280,
                          decoration: InputDecoration(
                            hintText: tr('comment_hint'),
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('send'),
                        onPressed: _busy ? null : _sendComment,
                        icon: Icon(Icons.send, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 18,
                        color: m.confirmations > 0 ? Colors.greenAccent : Colors.white38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(status, style: const TextStyle(fontSize: 13))),
                      Text(
                        tr('expires_in', {'t': duration(m.expiresAt.difference(DateTime.now()))}),
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                if (m.address != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '${tr('address')}: ${m.address}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            onPressed: _busy
                                ? null
                                : () => _run(() => repo.vote(m.id, actual: true),
                                    success: tr('voted'), close: true),
                            child: Text(tr('actual')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: BorderSide(color: scheme.primary),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _run(() => repo.vote(m.id, actual: false),
                                    success: tr('voted'), close: true),
                            child: Text(tr('not_actual')),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _commentsList() {
    final list = _comments;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(tr('no_comments'), style: const TextStyle(color: Colors.white60)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: list.length,
      itemBuilder: (_, i) => ListTile(
        dense: true,
        leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
        title: Text(list[i].text),
        subtitle: Text(timeAgo(list[i].createdAt)),
      ),
    );
  }
}
