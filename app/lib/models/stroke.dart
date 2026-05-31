import 'package:flutter/material.dart';

/// 한 번의 터치(펜 다운 → 무브 → 업)로 만들어진 하나의 선.
/// 점들의 집합 + 색/굵기/지우개 여부를 가진다.
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  Stroke copyWith({List<Offset>? points}) => Stroke(
        points: points ?? this.points,
        color: color,
        width: width,
        isEraser: isEraser,
      );
}
