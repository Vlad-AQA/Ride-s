import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Ошибка от сервера; [message] — код вроде `too_far:120`, см. errorText().
class ServerError implements Exception {
  ServerError(this.message);
  final String message;
}

class Repo {
  final _db = Supabase.instance.client;

  /// Все живые метки, по id. Обновляется онлайн.
  final markers = ValueNotifier<Map<String, RoadMarker>>({});

  /// Какие типы показывать на карте.
  final visibleTypes = ValueNotifier<Set<MarkerType>>(MarkerType.values.toSet());

  RealtimeChannel? _channel;
  Timer? _pruneTimer;

  String? get userId => _db.auth.currentUser?.id;

  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList('hidden_types') ?? [];
      visibleTypes.value = MarkerType.values.where((t) => !hidden.contains(t.key)).toSet();
    } catch (_) {
      // Фильтр не прочитался — показываем все типы.
    }

    if (_db.auth.currentSession == null) await _db.auth.signInAnonymously();

    _channel = _db
        .channel('markers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'markers',
          callback: (change) {
            if (change.eventType == PostgresChangeEvent.delete) {
              _remove(change.oldRecord['id'] as String?);
            } else {
              _put(RoadMarker.fromJson(change.newRecord));
            }
          },
        )
        .subscribe((status, _) {
      // После переподключения могли пропустить изменения — перечитываем.
      if (status == RealtimeSubscribeStatus.subscribed) refresh();
    });

    _pruneTimer = Timer.periodic(const Duration(seconds: 30), (_) => _prune());
  }

  Future<void> refresh() async {
    final rows = await _db
        .from('markers')
        .select()
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());
    markers.value = {
      for (final r in rows) r['id'] as String: RoadMarker.fromJson(r),
    };
  }

  Future<void> setTypeVisible(MarkerType type, bool visible) async {
    final next = {...visibleTypes.value};
    visible ? next.add(type) : next.remove(type);
    visibleTypes.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'hidden_types',
      MarkerType.values.where((t) => !next.contains(t)).map((t) => t.key).toList(),
    );
  }

  Future<RoadMarker> addMarker({
    required MarkerType type,
    required LatLng point,
    required LatLng me,
    String? address,
    String? comment,
  }) async {
    final row = await _rpc('add_marker', {
      'p_type': type.key,
      'p_lat': point.latitude,
      'p_lng': point.longitude,
      'p_user_lat': me.latitude,
      'p_user_lng': me.longitude,
      'p_address': address,
      'p_comment': comment,
    });
    final m = RoadMarker.fromJson(row);
    _put(m);
    return m;
  }

  Future<RoadMarker> vote(String markerId, {required bool actual}) async {
    final m = RoadMarker.fromJson(
      await _rpc('vote_marker', {'p_marker': markerId, 'p_actual': actual}),
    );
    _put(m);
    return m;
  }

  Future<List<MarkerComment>> comments(String markerId) async {
    final rows = await _db
        .from('comments')
        .select('text, created_at')
        .eq('marker_id', markerId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(MarkerComment.fromJson).toList();
  }

  Future<void> addComment(String markerId, String text) =>
      _rpc('add_comment', {'p_marker': markerId, 'p_text': text});

  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return Map<String, dynamic>.from(await _db.rpc(fn, params: params) as Map);
    } on PostgrestException catch (e) {
      throw ServerError(e.message);
    }
  }

  void _put(RoadMarker m) {
    final next = {...markers.value};
    m.isAlive ? next[m.id] = m : next.remove(m.id);
    markers.value = next;
  }

  void _remove(String? id) {
    if (id == null || !markers.value.containsKey(id)) return;
    markers.value = {...markers.value}..remove(id);
  }

  void _prune() {
    final alive = {
      for (final e in markers.value.entries)
        if (e.value.isAlive) e.key: e.value,
    };
    // Переприсваиваем и без удалений: цвет «свежести» пинов зависит от времени.
    markers.value = alive;
  }

  void dispose() {
    _pruneTimer?.cancel();
    _channel?.unsubscribe();
  }
}
