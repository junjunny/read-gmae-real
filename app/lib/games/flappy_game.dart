import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
    _vy = -0.018;
  }

  void _tick() {
    if (!_running) return;
    _frame++;
    if (_invincible > 0) _invincible--;
    if (_wide > 0) _wide--;

    // 중력
    _vy += 0.0010;
    _birdY += _vy;

    // 파이프 스폰(약 1.5초마다)
    if (_pipes.isEmpty || _pipes.last.x < 0.62) {
      final gapY = 0.22 + _rng.nextDouble() * 0.56;
      final gapHalf = _wide > 0 ? 0.24 : 0.16;
      _pipes.add(_Pipe(1.15, gapY, gapHalf));
      // 가끔 아이템 등장(파이프 사이 빈 공간)
      if (_rng.nextInt(100) < 40) {
        _items.add(_Item(1.15 + 0.31, 0.2 + _rng.nextDouble() * 0.6, _rng.nextInt(2)));
      }
    }

    // 이동
    const speed = 0.006;
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
      appBar: AppBar(title: Text('플래피버드 🐦   $_score${_invincible > 0 ? '   ⭐무적' : ''}${_wide > 0 ? '   ↔️' : ''}')),
      body: GestureDetector(
        onTap: _flap,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return Container(
            color: const Color(0xFF81D4FA),
            child: Stack(
              children: [
                // 파이프
                for (final p in _pipes) ...[
                  Positioned(
                    left: p.x * w,
                    top: 0,
                    width: _pipeW * w,
                    height: (p.gapY - p.gapHalf) * h,
                    child: Container(color: const Color(0xFF43A047)),
                  ),
                  Positioned(
                    left: p.x * w,
                    top: (p.gapY + p.gapHalf) * h,
                    width: _pipeW * w,
                    bottom: 0,
                    child: Container(color: const Color(0xFF43A047)),
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
                    child: const FittedBox(child: Text('🐦', style: TextStyle(fontSize: 30))),
                  ),
                ),
                if (!_running)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16)),
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
