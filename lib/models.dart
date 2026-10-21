import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';

enum MarkerType {
  checkpoint(Icons.local_police),
  motoPatrol(Icons.two_wheeler),
  touristCheck(Icons.badge_outlined),
  alcohol(Icons.local_bar),
  drugTest(Icons.science_outlined),
  highway(Icons.speed),
  camera(Icons.photo_camera_outlined),
  hazard(Icons.warning_amber_rounded);

  const MarkerType(this.icon);
  final IconData icon;

  // Имя типа в базе: motoPatrol -> moto_patrol.
  String get key => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  static MarkerType fromKey(String key) =>
      values.firstWhere((t) => t.key == key, orElse: () => checkpoint);
}

class RoadMarker {
  RoadMarker({
    required this.id,
    required this.type,
    required this.point,
    required this.address,
    required this.authorId,
    required this.createdAt,
    required this.lastConfirmedAt,
    required this.expiresAt,
    required this.confirmations,
    required this.commentsCount,
  });

  final String id;
  final MarkerType type;
  final LatLng point;
  final String? address;
  final String authorId;
  final DateTime createdAt;
  final DateTime? lastConfirmedAt;
  final DateTime expiresAt;
  final int confirmations;
  final int commentsCount;

  factory RoadMarker.fromJson(Map<String, dynamic> j) => RoadMarker(
        id: j['id'] as String,
        type: MarkerType.fromKey(j['type'] as String),
        point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        address: j['address'] as String?,
        authorId: j['author_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        lastConfirmedAt:
            j['last_confirmed_at'] == null ? null : DateTime.parse(j['last_confirmed_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
        confirmations: j['confirmations'] as int,
        commentsCount: (j['comments_count'] as int?) ?? 0,
      );

  bool get isAlive => expiresAt.isAfter(DateTime.now());

  DateTime get lastSeenAt => lastConfirmedAt ?? createdAt;

  // Красный — видели меньше часа назад, жёлтый — давно.
  bool get isFresh => DateTime.now().difference(lastSeenAt) < freshFor;
}

class MarkerComment {
  MarkerComment({required this.text, required this.createdAt});

  final String text;
  final DateTime createdAt;

  factory MarkerComment.fromJson(Map<String, dynamic> j) => MarkerComment(
        text: j['text'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
