import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game_fx.dart';

/// 아보카도 점프 🥑: 자동으로 통통 튀며 위로! 좌/우를 누르고 있으면 그 방향으로 이동.
/// 플랫폼을 밟으면 자동 점프. 화면 밖으로 떨어지면 끝. 높이 올라갈수록 점수.
/// 🟩 일반 · 🟧 흔들 · 🟥 부서짐(한 번 밟으면) · 🟦 스프링(높이 점프) · ⭐별=3초 무적+자동상승.
class AvocadoGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const AvocadoGame({super.key, required this.onFinish});
  @override
  State<AvocadoGame> createState() => _AvocadoGameState();
}

const int _pNormal = 0, _pMoving = 1, _pBreak = 2, _pSpring = 3;
// 최고점일 때 아보카도가 머무는 화면 비율 / 아보카도 반지름(H) — 페인터와 공유.
const double _anchor = 0.42;
const double _r = 0.05;

class _Plat {
  double x; // 현재 중심 x(0~1)
  final double baseX;
  final double worldY;
  final int type;
  final double phase;
  bool broken = false;
  double brokenAge = 0;
  _Plat(this.baseX, this.worldY, this.type, this.phase) : x = baseX;
}

class _Star {
  double x;
  final double worldY;
  bool taken = false;
  _Star(this.x, this.worldY);
}

class _AvocadoGameState extends State<AvocadoGame> with SingleTickerProviderStateMixin {
  // 물리(세로는 화면높이 H 비율, 가로는 폭 W 비율 단위)
  static const double _gravity = 0.0016;
  static const double _jumpV = -0.0300;
  static const double _springV = -0.0520;
  static const double _platHalf = 0.11; // 플랫폼 절반 폭(W)

  final _rng = Random();
  double _x = 0.5, _vx = 0; // 가로 위치/속도
  double _ay = 0, _vy = _jumpV; // 아보카도 worldY / 세로속도
  double _camY = 0; // 카메라(최고점 추적, 작을수록 위)
  double _topWorldY = 0; // 가장 높은 플랫폼 worldY
  int _dir = 0; // -1 왼쪽, +1 오른쪽, 0 정지
  int _invincible = 0;
  int _frame = 0;
  int _score = 0;
  bool _running = false;

  // 렉 방지: 매 프레임 setState로 위젯 트리 전체를 다시 만들지 않는다.
  // Ticker로 물리만 갱신하고, repaint 알림으로 페인터(그림)만 다시 그린다.
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  Duration _last = Duration.zero;
  double _acc = 0;

  final List<_Plat> _platforms = [];
  final List<_Star> _stars = [];

  double _height() => -_camY; // 올라간 높이(H)

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    _acc += dt;
    var stepped = false;
    var guard = 0;
    // 60Hz 고정 스텝(고주사율 화면에서도 같은 속도). 과도한 누적은 5스텝으로 제한.
    while (_acc >= 16 && guard < 5) {
      _acc -= 16;
      guard++;
      _step();
      stepped = true;
      if (!_running) break;
    }
    if (stepped) _repaint.value++;
  }

  void _start() {
    _x = 0.5;
    _vx = 0;
    _ay = 0;
    _vy = _jumpV;
    _camY = 0;
    _dir = 0;
    _invincible = 0;
    _frame = 0;
    _score = 0;
    _platforms.clear();
    _stars.clear();
    // 시작 발판(바로 아래) + 위로 펼치기
    _platforms.add(_Plat(0.5, 0.10, _pNormal, 0));
    _topWorldY = 0.10;
    _fillAbove();
    _running = true;
    _last = Duration.zero;
    _acc = 0;
    _ticker.stop();
    _ticker.start();
    setState(() {});
  }

  // 난이도: 높이 올라갈수록 플랫폼 간격이 넓어진다(점프 가능 범위 내).
  double _gap() => 0.15 + min(0.085, _height() * 0.004);

  int _pickType() {
    final h = _height();
    final roll = _rng.nextDouble();
    const spring = 0.06;
    final moving = h > 3 ? min(0.22, 0.05 + h * 0.012) : 0.0;
    final brk = h > 5 ? min(0.24, 0.04 + (h - 5) * 0.012) : 0.0;
    if (roll < spring) return _pSpring;
    if (roll < spring + moving) return _pMoving;
    if (roll < spring + moving + brk) return _pBreak;
    return _pNormal;
  }

  void _fillAbove() {
    while (_topWorldY > _camY - 1.4) {
      final ny = _topWorldY - _gap();
      final type = _pickType();
      final x = 0.12 + _rng.nextDouble() * 0.76;
      _platforms.add(_Plat(x, ny, type, _rng.nextDouble() * 2 * pi));
      // 가끔 별(무적) 등장 — 플랫폼 위쪽 빈 공간
      if (_rng.nextInt(100) < 7) {
        _stars.add(_Star(0.12 + _rng.nextDouble() * 0.76, ny - _gap() * 0.5));
      }
      _topWorldY = ny;
    }
  }

  void _step() {
    if (!_running) return;
    _frame++;

    // 가로 이동(부드럽게 목표 속도로 수렴) + 화면 양끝 wrap
    const moveSpeed = 0.017;
    _vx += (_dir * moveSpeed - _vx) * 0.25;
    _x += _vx;
    if (_x < 0) _x += 1;
    if (_x > 1) _x -= 1;

    // 흔들리는 플랫폼 위치 갱신
    for (final p in _platforms) {
      if (p.type == _pMoving) {
        p.x = (p.baseX + 0.16 * sin(_frame * 0.03 + p.phase)).clamp(0.06, 0.94);
      }
      if (p.broken) p.brokenAge += 1;
    }
    _platforms.removeWhere((p) => p.broken && p.brokenAge > 16);

    if (_invincible > 0) {
      _invincible--;
      _vy = -0.034; // 자동 상승
      _ay += _vy;
    } else {
      final prevFoot = _ay + _r;
      _vy += _gravity;
      if (_vy > 0.05) _vy = 0.05;
      _ay += _vy;
      final foot = _ay + _r;
      if (_vy > 0) {
        for (final p in _platforms) {
          if (p.broken) continue;
          final top = p.worldY;
          if (prevFoot <= top && foot >= top) {
            var dx = (_x - p.x).abs();
            dx = min(dx, 1 - dx); // wrap 고려
            if (dx < _platHalf + 0.055) {
              _ay = top - _r;
              _vy = p.type == _pSpring ? _springV : _jumpV;
              if (p.type == _pBreak) p.broken = true; // 한 번 밟으면 부서짐
              break;
            }
          }
        }
      }
    }

    // 카메라(최고점만 따라 위로)
    if (_ay < _camY) _camY = _ay;
    final sc = (_height() * 100).round();
    if (sc > _score) _score = sc;

    // 별 획득
    for (final s in _stars) {
      if (s.taken) continue;
      var dx = (_x - s.x).abs();
      dx = min(dx, 1 - dx);
      if (dx < 0.08 && (_ay - s.worldY).abs() < 0.06) {
        s.taken = true;
        _invincible = 188; // 약 3초
      }
    }
    _stars.removeWhere((s) => s.taken || s.worldY > _camY + 0.9);
    _platforms.removeWhere((p) => p.worldY > _camY + 0.9);
    _fillAbove();

    // 추락 판정(화면 아래로 벗어남)
    if (_invincible == 0 && (_ay - _camY) > (1.06 - _anchor)) {
      _end();
    }
  }

  void _end() {
    _running = false;
    _ticker.stop();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (_, __, ___) => Text('🥑 $_score${_invincible > 0 ? '   ⭐무적' : ''}'),
        ),
      ),
      body: Stack(
        children: [
          // 배경(우주 테마 — 한 번만 그려지는 정적 레이어, 매 프레임 비용 없음)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _SpaceBgPainter()),
            ),
          ),
          // 게임 그림(자체 RepaintBoundary + repaint 알림으로 페인터만 갱신)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _AvocadoPainter(this, repaint: _repaint),
              ),
            ),
          ),
          // 좌/우 조작(누르고 있으면 그 방향으로 이동)
          if (_running)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: _steer(-1, Alignment.bottomLeft, Icons.chevron_left)),
                  Expanded(child: _steer(1, Alignment.bottomRight, Icons.chevron_right)),
                ],
              ),
            ),
          if (!_running)
            Center(
              child: GestureDetector(
                onTap: _start,
                child: PopPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _score > 0
                            ? '게임 오버!  높이 $_score 🥑'
                            : '아보카도가 자동으로 통통!\n좌/우를 눌러(꾹) 방향을 잡아\n발판을 밟고 최대한 높이 올라가요\n⭐별=3초 무적+자동상승',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _steer(int dir, Alignment align, IconData icon) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _dir = dir,
      onTapUp: (_) => _dir = 0,
      onTapCancel: () => _dir = 0,
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0x592E7D32), // 35% 불투명(saveLayer 없이)
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 34),
          ),
        ),
      ),
    );
  }
}

class _AvocadoPainter extends CustomPainter {
  final _AvocadoGameState g;
  _AvocadoPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  double _sy(double worldY, double h) => (_anchor + (worldY - g._camY)) * h;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    for (final p in g._platforms) {
      final cy = _sy(p.worldY, h);
      if (cy < -40 || cy > h + 40) continue;
      _drawPlatform(canvas, p, p.x * w, cy, w);
    }

    for (final s in g._stars) {
      if (s.taken) continue;
      final cy = _sy(s.worldY, h);
      if (cy < -30 || cy > h + 30) continue;
      _drawStar(canvas, Offset(s.x * w, cy), w * 0.045, const Color(0xFFFFD54F));
    }

    if (g._running) {
      _drawAvocado(canvas, Offset(g._x * w, _sy(g._ay, h)), w * 0.13);
    }
  }

  // 색으로만 종류를 구분(가벼운 단색 렌더 — 렉 방지).
  // 🟩 일반 · 🟧 흔들 · 🟥 부서짐 · 🟦 스프링.
  void _drawPlatform(Canvas canvas, _Plat p, double cx, double cy, double w) {
    final pw = 0.22 * w, ph = pw * 0.26;
    Color base;
    switch (p.type) {
      case _pMoving:
        base = const Color(0xFFFFB300);
        break;
      case _pBreak:
        base = const Color(0xFFE53935);
        break;
      case _pSpring:
        base = const Color(0xFF26C6DA);
        break;
      default:
        base = const Color(0xFF66BB6A);
    }

    if (p.broken) {
      final t = (p.brokenAge / 16).clamp(0.0, 1.0);
      final a = 1 - t;
      final drop = t * 24;
      for (final s in const [-1, 1]) {
        final rect = Rect.fromCenter(
            center: Offset(cx + s * t * 22, cy + drop), width: pw / 2 - 3, height: ph);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(7)),
            Paint()..color = base.withValues(alpha: a));
      }
      return;
    }

    final rect = Rect.fromCenter(center: Offset(cx, cy + ph / 2), width: pw, height: ph);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(9)), Paint()..color = base);
  }

  // 귀여운 아보카도(원 2개로 부드러운 실루엣 + 씨앗 + 눈/미소). vy로 살짝 늘어남.
  void _drawAvocado(Canvas canvas, Offset c, double size) {
    final stretch = (1 + (g._vy * -3.5)).clamp(0.82, 1.18);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 / stretch.clamp(0.85, 1.15), stretch);
    final tilt = (g._vx * 6).clamp(-0.25, 0.25);
    canvas.rotate(tilt);

    final rr = size * 0.5;
    final bottom = Offset(0, rr * 0.18);
    final top = Offset(0, -rr * 0.75);
    final topR = rr * 0.62;

    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, rr + 6), width: size * 0.7, height: size * 0.2),
        Paint()..color = Colors.black.withValues(alpha: 0.12));

    // 몸통 실루엣(원 2개를 합쳐 부드럽게) + 어두운 우주 배경에서 잘 보이게 밝은 테두리
    final body = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: bottom, radius: rr)),
      Path()..addOval(Rect.fromCircle(center: top, radius: topR)),
    );
    canvas.drawPath(body, Paint()..color = const Color(0xFF386641));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFEAFBD0).withValues(alpha: 0.55));

    final flesh = Paint()..color = const Color(0xFFC9E4A6);
    canvas.drawCircle(bottom, rr * 0.74, flesh);
    canvas.drawCircle(top, topR * 0.7, flesh);

    final pit = Paint()..color = const Color(0xFF8D5524);
    canvas.drawCircle(bottom, rr * 0.34, pit);

    final eyeDx = (g._vx * 18).clamp(-3.0, 3.0);
    for (final s in const [-1.0, 1.0]) {
      final ec = Offset(s * topR * 0.42, top.dy - topR * 0.05);
      canvas.drawCircle(ec, topR * 0.26, Paint()..color = Colors.white);
      canvas.drawCircle(ec + Offset(eyeDx, 1), topR * 0.12, Paint()..color = const Color(0xFF222222));
    }
    final smile = Paint()
      ..color = const Color(0xFF3A2A1A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(0, top.dy + topR * 0.32), width: topR * 0.7, height: topR * 0.5),
        0.15 * pi, 0.7 * pi, false, smile);

    canvas.restore();

    if (g._invincible > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFD54F);
      canvas.drawCircle(c, size * 0.62, ring);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double rad, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final ang = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? rad : rad * 0.45;
      final pt = c + Offset(cos(ang) * rr, sin(ang) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(c, rad * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant _AvocadoPainter old) => true;
}

/// 우주 배경(정적): 밤하늘 그라데이션 + 별 + 초승달 + 작은 행성.
/// 한 번만 그려지고(매 프레임 비용 0) 화면 크기가 바뀔 때만 다시 그린다.
class _SpaceBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // 밤하늘 그라데이션
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14163A), Color(0xFF3A2B63), Color(0xFF7B63B0)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(rect));

    // 별(고정 시드 → 다시 그려도 같은 자리)
    final rng = Random(7);
    final star = Paint();
    for (var i = 0; i < 64; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.95;
      final r = rng.nextDouble() * 1.3 + 0.4;
      star.color = Colors.white.withValues(alpha: 0.3 + rng.nextDouble() * 0.55);
      canvas.drawCircle(Offset(x, y), r, star);
    }
    // 큰 반짝임 별(십자 모양)
    final spark = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.7;
      const s = 3.6;
      canvas.drawLine(Offset(x - s, y), Offset(x + s, y), spark);
      canvas.drawLine(Offset(x, y - s), Offset(x, y + s), spark);
    }

    // 초승달(오른쪽 위) — 두 원의 차집합으로 깔끔하게
    final moonC = Offset(w * 0.78, h * 0.12);
    final moonR = w * 0.10;
    // 은은한 달무리
    canvas.drawCircle(moonC, moonR * 1.5, Paint()..color = const Color(0x22FFF3C4));
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonC, radius: moonR)),
      Path()..addOval(Rect.fromCircle(center: moonC + Offset(moonR * 0.5, -moonR * 0.18), radius: moonR * 0.92)),
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFF3C4));

    // 작은 고리 행성(왼쪽 위)
    final planetC = Offset(w * 0.17, h * 0.22);
    final planetR = w * 0.052;
    canvas.drawCircle(planetC, planetR, Paint()..color = const Color(0xFFFFAB91));
    canvas.drawCircle(planetC + Offset(-planetR * 0.3, -planetR * 0.3), planetR * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.25));
    canvas.save();
    canvas.translate(planetC.dx, planetC.dy);
    canvas.rotate(-0.4);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: planetR * 3.4, height: planetR * 1.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFFFD180));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpaceBgPainter old) => false;
}
