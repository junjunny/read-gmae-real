import 'package:flutter/material.dart';
import '../models/stroke.dart';

/// CustomPainter — stroke 리스트를 그린다.
/// 고도화: 점 사이를 2차 베지어 곡선으로 보간해 손그림이 더 부드럽게 보이도록 함.
class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? current;
  final Color background;

  DrawingPainter({
    required this.strokes,
    this.current,
    this.background = Colors.white,
  });

  void _drawStroke(Canvas canvas, Stroke stroke) {
    final pts = stroke.points;
    if (pts.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (pts.length == 1) {
      canvas.drawCircle(pts.first, stroke.width / 2,
          paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    // 중점(midpoint) 베지어 스무딩
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 배경색
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    // 지우개(BlendMode.clear)는 별도 레이어에서 처리
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    if (current != null) _drawStroke(canvas, current!);
    canvas.restore();
  }

  @override
  // strokes 리스트를 같은 객체로 재사용하므로(되돌리기/삭제 시 내용만 변함),
  // 항상 다시 그리도록 한다. 캔버스가 가벼워 성능 문제 없음.
  bool shouldRepaint(covariant DrawingPainter old) => true;
}
