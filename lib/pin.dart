import 'package:flutter/material.dart';

import 'models.dart';

const pinRed = Color(0xFFE5243B);
const pinYellow = Color(0xFFF5C518);

const pinWidth = 40.0;
const pinHeight = 50.0;

/// Пин на карте: кружок с иконкой типа и «хвостик» вниз.
class Pin extends StatelessWidget {
  const Pin({super.key, required this.type, required this.fresh, this.hasComments = false});

  final MarkerType type;
  final bool fresh;
  final bool hasComments;

  @override
  Widget build(BuildContext context) {
    final color = fresh ? pinRed : pinYellow;
    final iconColor = fresh ? Colors.white : Colors.black87;
    return SizedBox(
      width: pinWidth,
      height: pinHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 30,
            child: Container(width: 3, height: 18, color: color),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black54)],
            ),
            child: Icon(type.icon, size: 19, color: iconColor),
          ),
          if (hasComments)
            Positioned(
              right: 0,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble, size: 9, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }
}
