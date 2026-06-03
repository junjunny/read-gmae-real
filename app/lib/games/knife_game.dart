import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

import 'game_fx.dart';

/// 나이프 던지기 🔪 (Knife Hit): 회전하는 통나무에 칼을 꽂는다.
/// 탭하면 칼이 날아가 통나무에 박힘 → 이미 박힌 칼과 부딪히면 게임 오버!
/// 🍎 사과를 맞히면 보너스. 스테이지를 깰수록 더 빨리·더 많은 칼이 박혀 있어 어려워진다.
class KnifeGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const KnifeGame({super.key, required this.onFinish});
  @override
  State<KnifeGame> createState() => _KnifeGameState();
}

class _KnifeGameState extends State<KnifeGame> {
  final _rng = Random();

  static const double _collisionGap = 0.26; // 칼이 차지하는 각(라디안, 한쪽)
  static const double _appleGap = 0.20;

  double _logAngle = 0; // 통나무 회전각
  double _angVel = 0.03; // 프레임당 회전(라디안)
  final List<double> _knives = []; // 박힌 칼들의 각(통나무 기준 상대각)
  final List<double> _apples = []; // 사과 각(상대각)

  int _score = 0, _stage = 1, _thrown = 0, _target = 7;
  bool _flying = false;
  double _flyT = 0; // 0→1 비행 진행
  bool _running = false;
  Timer? _loop;

  double _norm(double a) {
    a %= 2 * pi;
    return a < 0 ? a + 2 * pi : a;
  }

  double _angDist(double a, double b) {
    final d = (a - b).abs() % (2 * pi);
    return min(d, 2 * pi - d);
  }

  void _startStage(int stage) {
    _angVel = (0.028 + stage * 0.004) * (stage.isOdd ? 1 : -1);
    _target = 6 + stage;
    _thrown = 0;
    _flying = false;
    _flyT = 0;
    _knives.clear();
    _apples.clear();
    final pre = min(8, stage - 1); // 스테이지마다 미리 박힌 칼 증가
    var attempts = 0;
    while (_knives.length < pre && attempts < 300) {
      attempts++;
      final a = _rng.nextDouble() * 2 * pi;
      if (_knives.every((k) => _angDist(k, a) > 0.75)) _knives.add(a);
    }
    if (stage >= 2 && _rng.nextBool()) {
      var att = 0;
      while (att < 100) {
        att++;
        final a = _rng.nextDouble() * 2 * pi;
        if (_knives.every((k) => _angDist(k, a) > 0.5)) {
          _apples.add(a);
          break;
        }
      }
    }
  }

  void _start() {
    _score = 0;
    _stage = 1;
    _logAngle = 0;
    _startStage(1);
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    setState(() {});
  }

  void _tap() {
    if (!_running) {
      _start();
      return;
    }
    if (!_flying) {
      _flying = true;
      _flyT = 0;
    }
  }

  void _tick() {
    if (!_running) return;
    _logAngle = _norm(_logAngle + _angVel);
    if (_flying) {
      _flyT += 0.13;
      if (_flyT >= 1) _land();
    }
    setState(() {});
  }

  void _land() {
    _flying = false;
    _flyT = 0;
    // 아래(통나무 바닥)에 박힘 → 화면 down 방향 = +y = 각 pi/2
    final rel = _norm(pi / 2 - _logAngle);
    // 칼끼리 충돌 → 게임 오버
    if (_knives.any((k) => _angDist(k, rel) < _collisionGap)) {
      _end();
      return;
    }
    // 사과 명중 보너스
    final ai = _apples.indexWhere((a) => _angDist(a, rel) < _appleGap + 0.06);
    if (ai >= 0) {
      _apples.removeAt(ai);
      _score += 5;
    }
    _knives.add(rel);
    _score += 1;
    _thrown++;
    if (_thrown >= _target) {
      _stage++;
      _score += 20; // 스테이지 클리어 보너스
      _startStage(_stage);
    }
  }

  void _end() {
    _running = false;
    _loop?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: GameTitle('🔪  $_score')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF223349), Color(0xFF0E1825)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _KnifePainter(
                    logAngle: _logAngle,
                    knives: _knives,
                    apples: _apples,
                    flying: _flying && _running,
                    flyT: _flyT,
                    showReady: _running && !_flying,
                  ),
                ),
              ),
              if (_running)
                Align(
                  alignment: const Alignment(0, -0.62),
                  child: Text('남은 칼  ${'🔪' * (_target - _thrown)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              if (!_running)
                Center(
                  child: PopPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_score > 0 ? '게임 오버! 스테이지 $_stage · 점수 $_score 🔪' : '탭해서 칼 던지기!\n칼끼리 부딪히면 끝 · 🍎사과 보너스\n스테이지를 깰수록 점점 빨라져요', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnifePainter extends CustomPainter {
  final double logAngle;
  final List<double> knives;
  final List<double> apples;
  final bool flying;
  final double flyT;
  final bool showReady;
  _KnifePainter({
    required this.logAngle,
    required this.knives,
    required this.apples,
    required this.flying,
    required this.flyT,
    required this.showReady,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final r = size.width * 0.26;

    // 통나무(나이테)
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(center, r * 0.72, Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06);
    canvas.drawCircle(center, r * 0.4, Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05);
    canvas.drawCircle(center, r * 0.12, Paint()..color = const Color(0xFF4E342E));

    // 박힌 칼들
    for (final k in knives) {
      _drawKnifeRadial(canvas, center, r, k + logAngle);
    }
    // 사과
    for (final a in apples) {
      final w = a + logAngle;
      final p = center + Offset(cos(w), sin(w)) * r;
      canvas.drawCircle(p, r * 0.13, Paint()..color = const Color(0xFFE53935));
      canvas.drawCircle(p + Offset(0, -r * 0.13), r * 0.04, Paint()..color = const Color(0xFF43A047));
    }

    // 날아가는 칼 / 대기 칼 (화면 아래 → 통나무 바닥)
    final readyY = size.height * 0.9;
    final tipTargetY = center.dy + r; // 통나무 바닥 접점
    if (flying) {
      final tipY = readyY - (readyY - tipTargetY) * flyT.clamp(0.0, 1.0);
      _drawKnifeVertical(canvas, center.dx, tipY);
    } else if (showReady) {
      _drawKnifeVertical(canvas, center.dx, readyY);
    }
  }

  // 통나무에 박힌 칼: 접점에서 바깥으로 뻗는 칼날 + 손잡이
  void _drawKnifeRadial(Canvas canvas, Offset center, double r, double world) {
    final dir = Offset(cos(world), sin(world));
    final tip = center + dir * (r - 4); // 살짝 박힘
    final bladeEnd = center + dir * (r + 34);
    final handleEnd = center + dir * (r + 54);
    canvas.drawLine(tip, bladeEnd, Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(bladeEnd, handleEnd, Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
  }

  // 수직 칼(칼끝이 위를 향함)
  void _drawKnifeVertical(Canvas canvas, double x, double tipY) {
    canvas.drawLine(Offset(x, tipY), Offset(x, tipY + 36), Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(x, tipY + 36), Offset(x, tipY + 56), Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _KnifePainter old) => true;
}
