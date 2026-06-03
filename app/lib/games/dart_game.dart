import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_fx.dart';

/// 다트 게임 🎯: 좌우로 흔들리는 과녁에 타이밍 맞춰 다트를 던진다.
/// 중앙(불스아이)에 가까울수록 높은 점수(10→1). 총 10발. 후반부일수록 흔들림이
/// 빨라지고 폭도 넓어진다. 연속 불스아이는 콤보 보너스(+5씩).
class DartGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const DartGame({super.key, required this.onFinish});
  @override
  State<DartGame> createState() => _DartGameState();
}

/// 과녁에 박힌 다트(과녁 중심 기준 상대 오프셋 px). wob: 박힌 직후 흔들림(감쇠).
class _Stuck {
  final double ox, oy;
  final int score;
  double wob;
  _Stuck(this.ox, this.oy, this.score, this.wob);
}

class _Ripple {
  final double ox, oy;
  double age;
  _Ripple(this.ox, this.oy, this.age);
}

class _DartGameState extends State<DartGame> {
  static const int _totalDarts = 10;

  double _phase = 0; // 과녁 좌우 흔들림 위상
  double _omega = 0.034; // 흔들림 속도(라디안/프레임)
  double _amp = 0.16; // 흔들림 진폭(화면폭 비율)

  final List<_Stuck> _stuck = [];
  final List<_Ripple> _ripples = [];

  int _score = 0;
  int _dartsLeft = _totalDarts;
  int _combo = 0; // 연속 불스아이
  bool _flying = false;
  double _flyT = 0; // 0→1 비행 진행
  int _cooldown = 0; // 박힌 뒤 다음 다트 장전까지(프레임)
  int _frame = 0;
  String? _flash;
  int _flashAge = 0;
  bool _running = false;
  Timer? _loop;
  Size _size = Size.zero;
  final _rng = Random();

  double _easeOut(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  void _setDifficulty() {
    final t = _totalDarts - _dartsLeft; // 0..9
    _omega = 0.034 + t * 0.0062;
    _amp = 0.16 + t * 0.013;
  }

  void _start() {
    _stuck.clear();
    _ripples.clear();
    _score = 0;
    _dartsLeft = _totalDarts;
    _combo = 0;
    _flying = false;
    _flyT = 0;
    _cooldown = 0;
    _phase = 0;
    _flash = null;
    _setDifficulty();
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
    if (!_flying && _cooldown == 0 && _dartsLeft > 0) {
      _flying = true;
      _flyT = 0;
    }
  }

  void _tick() {
    if (!_running) return;
    _frame++;
    _phase += _omega;
    if (_flying) {
      _flyT += 0.05; // 약 20프레임(=0.32초) 비행
      if (_flyT >= 1) _stick();
    }
    if (_cooldown > 0) {
      _cooldown--;
      if (_cooldown == 0 && _dartsLeft == 0) {
        _end();
        return;
      }
    }
    for (final r in _ripples) {
      r.age += 1;
    }
    _ripples.removeWhere((r) => r.age > 22);
    for (final s in _stuck) {
      if (s.wob.abs() > 0.001) s.wob *= 0.86;
    }
    if (_flash != null && ++_flashAge > 46) _flash = null;
    setState(() {});
  }

  void _stick() {
    _flying = false;
    _flyT = 0;
    final w = _size.width;
    if (w <= 0) return;
    final cx = w / 2 + _amp * w * sin(_phase);
    final ox = w / 2 - cx; // 과녁 중심 기준 다트의 수평 오프셋
    final boardR = w * 0.28;
    final ring = (ox.abs() / (boardR / 10)).floor(); // 0=불스아이 … 9=가장자리
    final sc = ring > 9 ? 0 : 10 - ring;
    final oy = (_rng.nextDouble() * 2 - 1) * boardR * 0.05;
    _stuck.add(_Stuck(ox, oy, sc, 1.0));
    _ripples.add(_Ripple(ox, oy, 0));
    _score += sc;
    if (ring == 0) {
      _combo++;
      if (_combo >= 2) {
        final bonus = (_combo - 1) * 5;
        _score += bonus;
        _flash = '🎯 불스아이! 콤보 x$_combo  +$bonus';
      } else {
        _flash = '🎯 불스아이!  +10';
      }
    } else {
      _combo = 0;
      _flash = sc == 0 ? '빗나감!' : '+$sc';
    }
    _flashAge = 0;
    _dartsLeft--;
    _setDifficulty();
    _cooldown = 14; // 약 0.22초 뒤 다음 다트 장전
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
      appBar: AppBar(title: Text('🎯 $_score')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: LayoutBuilder(builder: (context, box) {
          _size = Size(box.maxWidth, box.maxHeight);
          return Container(
            decoration: bgGradient(const [Color(0xFF243B55), Color(0xFF141E30)]),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DartPainter(
                      phase: _phase,
                      amp: _amp,
                      stuck: _stuck,
                      ripples: _ripples,
                      flying: _flying && _running,
                      flyT: _easeOut(_flyT),
                      showReady: _running && !_flying && _cooldown == 0 && _dartsLeft > 0,
                      frame: _frame,
                    ),
                  ),
                ),
                if (_running)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text('남은 다트  ${'🎯' * _dartsLeft}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        if (_combo >= 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('🔥 콤보 x$_combo',
                                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                if (_flash != null && _running)
                  Align(
                    alignment: const Alignment(0, 0.42),
                    child: AnimatedOpacity(
                      opacity: _flashAge < 36 ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(_flash!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                          )),
                    ),
                  ),
                if (!_running)
                  Center(
                    child: PopPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _score > 0
                                ? '게임 오버!  점수 $_score 🎯'
                                : '탭해서 다트 던지기!\n흔들리는 과녁 중앙(불스아이)을 노려요\n총 10발 · 연속 불스아이 콤보 보너스',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DartPainter extends CustomPainter {
  final double phase, amp, flyT;
  final List<_Stuck> stuck;
  final List<_Ripple> ripples;
  final bool flying, showReady;
  final int frame;
  _DartPainter({
    required this.phase,
    required this.amp,
    required this.stuck,
    required this.ripples,
    required this.flying,
    required this.flyT,
    required this.showReady,
    required this.frame,
  });

  // 양궁 과녁 색(중심→바깥): 금·빨강·파랑·검정·흰색, 각 2점씩 → 10..1점.
  static const List<Color> _band = [
    Color(0xFFFFD93B), Color(0xFFFF5A5F), Color(0xFF4FC3F7), Color(0xFF2E2E2E), Color(0xFFF5F5F5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final boardCY = h * 0.34;
    final boardR = w * 0.28;
    final cx = w / 2 + amp * w * sin(phase);
    final center = Offset(cx, boardCY);
    final launchTipY = h * 0.9;

    // 과녁 그림자
    canvas.drawCircle(center + const Offset(0, 6), boardR,
        Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // 링(바깥→안쪽)
    for (var b = 4; b >= 0; b--) {
      canvas.drawCircle(center, boardR * (b + 1) * 0.2, Paint()..color = _band[b]);
      // 링 경계 얇은 선
      canvas.drawCircle(center, boardR * (b + 1) * 0.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withValues(alpha: 0.12));
    }
    // 바깥 테두리 + 불스아이 점
    canvas.drawCircle(center, boardR, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF0E1A2B));
    canvas.drawCircle(center, boardR * 0.06, Paint()..color = const Color(0xFFB8860B));

    // 충돌 파동
    for (final r in ripples) {
      final t = (r.age / 22).clamp(0.0, 1.0);
      canvas.drawCircle(center + Offset(r.ox, r.oy), boardR * (0.06 + t * 0.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - t)
            ..color = Colors.white.withValues(alpha: (1 - t) * 0.8));
    }

    // 박힌 다트(과녁과 함께 이동) — 아래쪽으로 살짝 솟아 박힌 모습 + 잔진동
    for (final s in stuck) {
      final p = center + Offset(s.ox, s.oy);
      final wob = s.wob * 0.22 * sin(frame * 0.9);
      _drawStuckDart(canvas, p, wob);
    }

    // 날아가는 다트 / 대기 다트(화면 아래 중앙에서 수직 상승)
    final dartX = w / 2;
    if (flying) {
      final tipY = launchTipY - (launchTipY - boardCY) * flyT;
      // 모션 트레일(잔상)
      for (var i = 1; i <= 3; i++) {
        final ft = (flyT - i * 0.05).clamp(0.0, 1.0);
        final ty = launchTipY - (launchTipY - boardCY) * ft;
        _drawFlyingDart(canvas, dartX, ty, alpha: 0.16 * (3 - i + 1) / 3);
      }
      _drawFlyingDart(canvas, dartX, tipY, alpha: 1);
    } else if (showReady) {
      _drawFlyingDart(canvas, dartX, launchTipY, alpha: 1);
      // 조준 가이드(은은한 점선)
      final guide = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 2;
      for (var y = boardCY + boardR + 16; y < launchTipY; y += 18) {
        canvas.drawLine(Offset(dartX, y), Offset(dartX, y + 8), guide);
      }
    }
  }

  // 비행 중인 다트(칼끝이 위). tip = (x, tipY).
  void _drawFlyingDart(Canvas canvas, double x, double tipY, {required double alpha}) {
    final shaft = Paint()
      ..color = const Color(0xFFE0E0E0).withValues(alpha: alpha)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final tail = Paint()..color = const Color(0xFFFF5A5F).withValues(alpha: alpha);
    // 촉
    final tip = Path()
      ..moveTo(x, tipY)
      ..lineTo(x - 4, tipY + 10)
      ..lineTo(x + 4, tipY + 10)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFBDBDBD).withValues(alpha: alpha));
    // 샤프트
    canvas.drawLine(Offset(x, tipY + 8), Offset(x, tipY + 46), shaft);
    // 꼬리 날개
    canvas.drawPath(
        Path()
          ..moveTo(x, tipY + 40)
          ..lineTo(x - 9, tipY + 56)
          ..lineTo(x, tipY + 50)
          ..close(),
        tail);
    canvas.drawPath(
        Path()
          ..moveTo(x, tipY + 40)
          ..lineTo(x + 9, tipY + 56)
          ..lineTo(x, tipY + 50)
          ..close(),
        tail);
  }

  // 과녁에 박힌 다트: 촉이 점 p에, 샤프트가 아래로 솟음. wob 만큼 살짝 회전.
  void _drawStuckDart(Canvas canvas, Offset p, double wob) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(wob);
    final shaft = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 2), const Offset(0, 40), shaft);
    final tail = Paint()..color = const Color(0xFFFF5A5F);
    canvas.drawPath(Path()..moveTo(0, 34)..lineTo(-9, 50)..lineTo(0, 44)..close(), tail);
    canvas.drawPath(Path()..moveTo(0, 34)..lineTo(9, 50)..lineTo(0, 44)..close(), tail);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DartPainter old) => true;
}
