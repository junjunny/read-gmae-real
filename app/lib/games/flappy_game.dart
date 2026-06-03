import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

import 'game_fx.dart';

/// 플래피버드 🐦: 탭해서 날아올라 파이프 사이를 통과! 통과할 때마다 +1점.
/// ⭐ 별을 먹으면 3초 무적 / ↔️ 아이템을 먹으면 잠깐 파이프 간격이 넓어진다.
class FlappyGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const FlappyGame({super.key, required this.onFinish});
  @override
  State<FlappyGame> createState() => _FlappyGameState();
}

class _Pipe {
  double x; // 0~1+ (왼쪽으로 스크롤)
  final double gapY; // 간격 중심(0~1)
  final double gapHalf; // 간격 절반 높이
  bool scored = false;
  _Pipe(this.x, this.gapY, this.gapHalf);
}

class _Item {
  double x;
  final double y;
  final int type; // 0=별(무적), 1=간격 넓힘
  _Item(this.x, this.y, this.type);
}

// 10점마다 바뀌는 하늘 테마(맑음→노을→밤→…). 색만 바꾸므로 가볍다.
const List<List<Color>> _skies = [
  [Color(0xFFB3E5FC), Color(0xFF4FC3F7)], // 맑은 낮
  [Color(0xFFFFE0B2), Color(0xFFFFB74D)], // 아침
  [Color(0xFFFFCCBC), Color(0xFFFF8A65)], // 석양
  [Color(0xFFF8BBD0), Color(0xFFCE93D8)], // 분홍노을
  [Color(0xFFB39DDB), Color(0xFF7E57C2)], // 보랏빛 저녁
  [Color(0xFF5C6BC0), Color(0xFF283593)], // 푸른 밤
  [Color(0xFF26323E), Color(0xFF0D1B3E)], // 깊은 밤
  [Color(0xFF80DEEA), Color(0xFF26C6DA)], // 청량
];

class _FlappyGameState extends State<FlappyGame> {
  static const double _birdX = 0.28;
  static const double _birdR = 0.04;
  static const double _pipeW = 0.14;

  final _rng = Random();
  double _birdY = 0.5, _vy = 0;
  final List<_Pipe> _pipes = [];
  final List<_Item> _items = [];
  int _score = 0;
  int _invincible = 0; // 잔여 프레임(무적)
  int _wide = 0; // 잔여 프레임(간격 넓힘)
  int _frame = 0;
  bool _running = false;
  Timer? _loop;

  void _start() {
    _birdY = 0.5;
    _vy = 0;
    _pipes.clear();
    _items.clear();
    _score = 0;
    _invincible = 0;
    _wide = 0;
    _frame = 0;
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    setState(() {});
  }

  void _flap() {
    if (!_running) {
      _start();
      return;
    }
    _vy = -0.0135; // 점프 완화(덜 민감하게)
  }

  void _tick() {
    if (!_running) return;
    _frame++;
    if (_invincible > 0) _invincible--;
    if (_wide > 0) _wide--;

    // 중력(완만하게) + 낙하 속도 상한
    _vy += 0.00060;
    if (_vy > 0.018) _vy = 0.018;
    _birdY += _vy;

    // 파이프 스폰(간격 넉넉하게)
    if (_pipes.isEmpty || _pipes.last.x < 0.40) {
      final gapY = 0.26 + _rng.nextDouble() * 0.48;
      final gapHalf = _wide > 0 ? 0.27 : 0.215; // 기본 간격 넓힘
      _pipes.add(_Pipe(1.15, gapY, gapHalf));
      // 가끔 아이템 등장(파이프 사이 빈 공간)
      if (_rng.nextInt(100) < 45) {
        _items.add(_Item(1.15 + 0.38, 0.22 + _rng.nextDouble() * 0.56, _rng.nextInt(2)));
      }
    }

    // 이동(스크롤 속도 완화)
    const speed = 0.0042;
    for (final p in _pipes) {
      p.x -= speed;
    }
    for (final it in _items) {
      it.x -= speed;
    }
    _pipes.removeWhere((p) => p.x < -_pipeW);
    _items.removeWhere((it) => it.x < -0.1);

    // 점수
    for (final p in _pipes) {
      if (!p.scored && p.x + _pipeW < _birdX) {
        p.scored = true;
        _score++;
      }
    }

    // 아이템 획득
    _items.removeWhere((it) {
      final hit = (it.x - _birdX).abs() < 0.06 && (it.y - _birdY).abs() < 0.06;
      if (hit) {
        if (it.type == 0) {
          _invincible = 188; // 약 3초
        } else {
          _wide = 312; // 약 5초
        }
      }
      return hit;
    });

    // 충돌 판정
    if (_invincible > 0) {
      _birdY = _birdY.clamp(0.0, 1.0);
    } else {
      if (_birdY < 0 || _birdY > 1) {
        _end();
        return;
      }
      for (final p in _pipes) {
        final overlapX = p.x < _birdX + _birdR && p.x + _pipeW > _birdX - _birdR;
        if (overlapX) {
          final inGap = _birdY > p.gapY - p.gapHalf + _birdR && _birdY < p.gapY + p.gapHalf - _birdR;
          if (!inGap) {
            _end();
            return;
          }
        }
      }
    }
    setState(() {});
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
      appBar: AppBar(title: GameTitle('🐦  $_score${_invincible > 0 ? '  ⭐무적' : ''}${_wide > 0 ? '  ↔️' : ''}')),
      body: GestureDetector(
        onTap: _flap,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final sky = _skies[(_score ~/ 10) % _skies.length];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: sky,
              ),
            ),
            child: Stack(
              children: [
                // 파이프
                for (final p in _pipes) ...[
                  Positioned(
                    left: p.x * w,
                    top: 0,
                    width: _pipeW * w,
                    height: (p.gapY - p.gapHalf) * h,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF66BB6A), Color(0xFF388E3C), Color(0xFF2E7D32)],
                          stops: [0.0, 0.45, 1.0],
                        ),
                        border: Border(
                          left: BorderSide(color: Color(0x33000000), width: 1),
                          right: BorderSide(color: Color(0x33000000), width: 1),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: p.x * w,
                    top: (p.gapY + p.gapHalf) * h,
                    width: _pipeW * w,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF66BB6A), Color(0xFF388E3C), Color(0xFF2E7D32)],
                          stops: [0.0, 0.45, 1.0],
                        ),
                        border: Border(
                          left: BorderSide(color: Color(0x33000000), width: 1),
                          right: BorderSide(color: Color(0x33000000), width: 1),
                        ),
                      ),
                    ),
                  ),
                ],
                // 아이템
                for (final it in _items)
                  Positioned(
                    left: it.x * w - 16,
                    top: it.y * h - 16,
                    width: 32,
                    height: 32,
                    child: Center(child: Text(it.type == 0 ? '⭐' : '↔️', style: const TextStyle(fontSize: 28))),
                  ),
                // 새
                Positioned(
                  left: _birdX * w - _birdR * w,
                  top: _birdY * h - _birdR * w,
                  width: _birdR * 2 * w,
                  height: _birdR * 2 * w,
                  child: Opacity(
                    opacity: _invincible > 0 && (_frame ~/ 5).isEven ? 0.4 : 1,
                    child: Transform.rotate(
                      angle: (_vy * 16).clamp(-0.5, 1.0), // 오를 땐 위로, 떨어질 땐 아래로 부드럽게 기울기
                      child: CustomPaint(painter: _BirdPainter(flap: (_frame ~/ 6).isEven)),
                    ),
                  ),
                ),
                if (!_running)
                  Center(
                    child: PopPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '꽝! 점수 $_score 🐦' : '탭해서 날아올라\n파이프를 통과하세요!\n⭐별=3초 무적 · ↔️=간격 넓힘', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
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

/// 귀여운 아기새(오른쪽을 보는 둥근 병아리). 날개는 flap 으로 퍼덕인다. 벡터라 가볍다.
class _BirdPainter extends CustomPainter {
  final bool flap;
  _BirdPainter({required this.flap});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.52);
    final r = w * 0.4;

    // 그림자
    canvas.drawCircle(c + Offset(0, r * 0.1), r, Paint()..color = Colors.black.withValues(alpha: 0.08));
    // 몸통
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD54F));
    // 배(연한)
    canvas.drawCircle(c + Offset(r * 0.05, r * 0.22), r * 0.7, Paint()..color = const Color(0xFFFFF59D));
    // 꼬리(왼쪽)
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - r * 0.8, c.dy)
          ..lineTo(c.dx - r * 1.3, c.dy - r * 0.25)
          ..lineTo(c.dx - r * 1.3, c.dy + r * 0.25)
          ..close(),
        Paint()..color = const Color(0xFFFFB300));
    // 날개(퍼덕임)
    canvas.save();
    canvas.translate(c.dx - r * 0.05, c.dy - r * 0.05);
    canvas.rotate(flap ? -0.5 : -0.05);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.0, height: r * 0.6), Paint()..color = const Color(0xFFFFB300));
    canvas.restore();
    // 부리(오른쪽, 주황 삼각형)
    canvas.drawPath(
        Path()
          ..moveTo(c.dx + r * 0.82, c.dy - r * 0.06)
          ..lineTo(c.dx + r * 1.22, c.dy + r * 0.04)
          ..lineTo(c.dx + r * 0.82, c.dy + r * 0.2)
          ..close(),
        Paint()..color = const Color(0xFFFF8F00));
    // 눈(크게 → 귀엽게)
    final eye = Offset(c.dx + r * 0.4, c.dy - r * 0.28);
    canvas.drawCircle(eye, r * 0.27, Paint()..color = Colors.white);
    canvas.drawCircle(eye + Offset(r * 0.07, 0), r * 0.14, Paint()..color = const Color(0xFF333333));
    canvas.drawCircle(eye + Offset(r * 0.13, -r * 0.05), r * 0.05, Paint()..color = Colors.white);
    // 볼터치
    canvas.drawCircle(c + Offset(r * 0.5, r * 0.28), r * 0.13, Paint()..color = const Color(0x55FF8A80));
  }

  @override
  bool shouldRepaint(covariant _BirdPainter old) => old.flap != flap;
}
