import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game_chrome.dart';
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
          builder: (_, __, ___) => GameTitle('🥑  $_score${_invincible > 0 ? '  ⭐무적' : ''}'),
        ),
      ),
      body: Stack(
        children: [
          // 배경은 게임 페인터 안에서 고도(점수)에 따라 함께 그린다(낮→우주→달→행성).
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

    // 고도(점수)에 따른 배경: ~2500 전 낮(태양+구름) → 우주(별) → 3500 달 → 5000 행성
    _drawBackground(canvas, size, g._score.toDouble(), g._camY);

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

  // 고도(점수)에 따라 배경을 그린다. 셰이프 위주라 가볍다(매 프레임 OK).
  // ~2500 전: 하늘+태양+구름 / 그 후: 우주(별) / 3500+: 노란 초승달 / 5000+: 고리 행성.
  void _drawBackground(Canvas canvas, Size size, double score, double camY) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final t = ((score - 2400) / 200).clamp(0.0, 1.0); // 0=낮 → 1=우주(2400~2600 전환)

    // 하늘 그라데이션(낮 ↔ 우주 크로스페이드)
    final top = Color.lerp(const Color(0xFF8FD3FF), const Color(0xFF14163A), t)!;
    final mid = Color.lerp(const Color(0xFFCDEBFF), const Color(0xFF3A2B63), t)!;
    final bot = Color.lerp(const Color(0xFFEAF7E9), const Color(0xFF7B63B0), t)!;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, mid, bot],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect));

    // 낮: 태양 + 구름
    final day = 1 - t;
    if (day > 0.01) {
      final sunC = Offset(w * 0.8, h * 0.14);
      canvas.drawCircle(sunC, w * 0.16, Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.35 * day));
      canvas.drawCircle(sunC, w * 0.10, Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.95 * day));
      _drawCloud(canvas, Offset(w * 0.26, h * 0.17), w * 0.16, day);
      _drawCloud(canvas, Offset(w * 0.62, h * 0.32), w * 0.20, day * 0.9);
      _drawCloud(canvas, Offset(w * 0.16, h * 0.46), w * 0.13, day * 0.8);
    }

    // 우주: 별(오를수록 아래로 흐르는 패럴랙스)
    if (t > 0.01) {
      final off = (-camY) * 0.12;
      final star = Paint();
      for (final s in _bgStars) {
        final y = ((s.y + off) % 1.0) * h;
        star.color = Colors.white.withValues(alpha: s.a * t);
        canvas.drawCircle(Offset(s.x * w, y), s.r, star);
      }
      final spark = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * t)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (final sp in _bgSparks) {
        final x = sp.dx * w, y = ((sp.dy + off) % 1.0) * h;
        const ss = 3.6;
        canvas.drawLine(Offset(x - ss, y), Offset(x + ss, y), spark);
        canvas.drawLine(Offset(x, y - ss), Offset(x, y + ss), spark);
      }
    }

    // 달(3500+): 그냥 노란 초승달
    final m = ((score - 3500) / 200).clamp(0.0, 1.0);
    if (m > 0.01) {
      final moonC = Offset(w * 0.76, h * 0.12);
      final moonR = w * 0.10;
      final crescent = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moonC, radius: moonR)),
        Path()..addOval(Rect.fromCircle(center: moonC + Offset(moonR * 0.5, -moonR * 0.18), radius: moonR * 0.92)),
      );
      canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFE082).withValues(alpha: m));
    }

    // 행성(5000+): 고리 달린 작은 행성
    final pl = ((score - 5000) / 200).clamp(0.0, 1.0);
    if (pl > 0.01) {
      final pc = Offset(w * 0.2, h * 0.2);
      final pr = w * 0.055;
      canvas.drawCircle(pc, pr, Paint()..color = const Color(0xFFFFAB91).withValues(alpha: pl));
      canvas.drawCircle(pc + Offset(-pr * 0.3, -pr * 0.3), pr * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.25 * pl));
      canvas.save();
      canvas.translate(pc.dx, pc.dy);
      canvas.rotate(-0.4);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: pr * 3.4, height: pr * 1.1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = const Color(0xFFFFD180).withValues(alpha: pl));
      canvas.restore();
    }

    // 7000+: 별똥별(코멧)이 천천히 가로지름
    final c7 = ((score - 7000) / 200).clamp(0.0, 1.0);
    if (c7 > 0.01) {
      _drawComet(canvas, w, h, 0, c7);
      _drawComet(canvas, w, h, 1, c7);
    }

    // 9000+: 성운(은은한 갤럭시 안개)
    final n9 = ((score - 9000) / 200).clamp(0.0, 1.0);
    if (n9 > 0.01) {
      _nebula(canvas, Offset(w * 0.30, h * 0.58), w * 0.34, const Color(0xFF7E57C2), n9);
      _nebula(canvas, Offset(w * 0.72, h * 0.44), w * 0.30, const Color(0xFFEC407A), n9 * 0.85);
      _nebula(canvas, Offset(w * 0.55, h * 0.72), w * 0.30, const Color(0xFF26C6DA), n9 * 0.7);
    }

    // 12000+: 귀여운 로켓이 둥둥 떠다님
    final r12 = ((score - 12000) / 200).clamp(0.0, 1.0);
    if (r12 > 0.01) {
      _drawRocket(canvas, w, h, r12);
    }

    // 15000+: 하트 별자리(커플 피날레 ✨)
    final h15 = ((score - 15000) / 200).clamp(0.0, 1.0);
    if (h15 > 0.01) {
      _drawHeart(canvas, w, h, h15);
    }
  }

  // 별똥별: 주기적으로 대각선으로 흐른다(프레임 기반, 가볍다).
  void _drawComet(Canvas canvas, double w, double h, int idx, double alpha) {
    const period = 240;
    final phase = ((g._frame + idx * 120) % period) / period; // 0~1
    final x = (-0.15 + phase * 1.35) * w;
    final y = (0.10 + idx * 0.22 + phase * 0.18) * h;
    final head = Offset(x, y);
    final tail = head - Offset(w * 0.13, w * 0.06);
    final fade = phase < 0.85 ? 1.0 : (1 - phase) / 0.15;
    final a = alpha * fade.clamp(0.0, 1.0);
    canvas.drawLine(
        tail,
        head,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * a)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(head, 2.6, Paint()..color = Colors.white.withValues(alpha: 0.95 * a));
  }

  // 성운: 셰이더/블러 없이 원 3겹으로 부드러운 안개 느낌.
  void _nebula(Canvas canvas, Offset c, double r, Color color, double alpha) {
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.10 * alpha));
    canvas.drawCircle(c, r * 0.66, Paint()..color = color.withValues(alpha: 0.14 * alpha));
    canvas.drawCircle(c, r * 0.36, Paint()..color = color.withValues(alpha: 0.20 * alpha));
  }

  // 귀여운 로켓: 오른쪽에서 살짝 흔들리며 떠다니고 불꽃이 깜빡인다(벡터, 가볍다).
  void _drawRocket(Canvas canvas, double w, double h, double alpha) {
    final bob = sin(g._frame * 0.05) * w * 0.02;
    final s = w * 0.06;
    canvas.save();
    canvas.translate(w * 0.76 + bob, h * 0.66);
    // 불꽃(깜빡임)
    final flick = 0.7 + 0.3 * sin(g._frame * 0.4);
    canvas.drawPath(
        Path()
          ..moveTo(-s * 0.34, s * 0.95)
          ..quadraticBezierTo(0, s * (1.55 + 0.5 * flick), s * 0.34, s * 0.95)
          ..close(),
        Paint()..color = const Color(0xFFFFA726).withValues(alpha: 0.9 * alpha));
    canvas.drawPath(
        Path()
          ..moveTo(-s * 0.2, s * 0.95)
          ..quadraticBezierTo(0, s * (1.25 + 0.4 * flick), s * 0.2, s * 0.95)
          ..close(),
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.95 * alpha));
    // 몸통
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 0.9, height: s * 1.9), Radius.circular(s * 0.45)),
        Paint()..color = Colors.white.withValues(alpha: alpha));
    // 코(빨강)
    canvas.drawPath(
        Path()
          ..moveTo(-s * 0.45, -s * 0.5)
          ..quadraticBezierTo(0, -s * 1.45, s * 0.45, -s * 0.5)
          ..close(),
        Paint()..color = const Color(0xFFEF5350).withValues(alpha: alpha));
    // 핀(양옆 빨강)
    final fin = Paint()..color = const Color(0xFFEF5350).withValues(alpha: alpha);
    canvas.drawPath(Path()..moveTo(-s * 0.45, s * 0.4)..lineTo(-s * 0.85, s * 0.95)..lineTo(-s * 0.45, s * 0.95)..close(), fin);
    canvas.drawPath(Path()..moveTo(s * 0.45, s * 0.4)..lineTo(s * 0.85, s * 0.95)..lineTo(s * 0.45, s * 0.95)..close(), fin);
    // 창문(파랑)
    canvas.drawCircle(Offset(0, -s * 0.15), s * 0.28, Paint()..color = const Color(0xFF42A5F5).withValues(alpha: alpha));
    canvas.drawCircle(Offset(-s * 0.08, -s * 0.23), s * 0.1, Paint()..color = Colors.white.withValues(alpha: 0.7 * alpha));
    canvas.restore();
  }

  // 하트 별자리: 점 8개 + 연결선(파라메트릭 하트).
  void _drawHeart(Canvas canvas, double w, double h, double alpha) {
    final cx = w * 0.5, cy = h * 0.17, s = w * 0.085;
    final pts = <Offset>[];
    for (var i = 0; i < 8; i++) {
      final tt = i / 8 * 2 * pi;
      final hx = 16 * pow(sin(tt), 3);
      final hy = 13 * cos(tt) - 5 * cos(2 * tt) - 2 * cos(3 * tt) - cos(4 * tt);
      pts.add(Offset(cx + (hx / 16.0) * s, cy - (hy / 16.0) * s));
    }
    final line = Paint()
      ..color = const Color(0xFFFFD1DC).withValues(alpha: 0.5 * alpha)
      ..strokeWidth = 1.3;
    for (var i = 0; i < pts.length; i++) {
      canvas.drawLine(pts[i], pts[(i + 1) % pts.length], line);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 2.4, Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha));
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double s, double alpha) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha);
    canvas.drawOval(Rect.fromCenter(center: c, width: s * 1.7, height: s * 0.7), p);
    canvas.drawCircle(c + Offset(-s * 0.45, 0), s * 0.42, p);
    canvas.drawCircle(c + Offset(s * 0.45, -s * 0.06), s * 0.46, p);
    canvas.drawCircle(c + Offset(0, -s * 0.22), s * 0.5, p);
  }

  @override
  bool shouldRepaint(covariant _AvocadoPainter old) => true;
}

/// 우주 배경 별(정규화 좌표 0~1, 반지름 px, 알파) — 고정 시드로 한 번만 생성.
class _BgStar {
  final double x, y, r, a;
  const _BgStar(this.x, this.y, this.r, this.a);
}

final List<_BgStar> _bgStars = () {
  final rng = Random(7);
  return List.generate(
      58, (_) => _BgStar(rng.nextDouble(), rng.nextDouble(), rng.nextDouble() * 1.3 + 0.4, 0.3 + rng.nextDouble() * 0.55));
}();

final List<Offset> _bgSparks = () {
  final rng = Random(19);
  return List.generate(6, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
}();
