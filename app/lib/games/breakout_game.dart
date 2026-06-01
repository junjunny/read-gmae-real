import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 벽돌깨기 🧱: 패들을 좌우로 움직여 공을 튕겨 벽돌을 부순다.
/// 떨어지는 아이템: 💥 x2 데미지 / ➕ 공 분열(2개) / 🧲 자석 패들(공이 붙었다 탭하면 발사).
class BreakoutGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const BreakoutGame({super.key, required this.onFinish});
  @override
  State<BreakoutGame> createState() => _BreakoutGameState();
}

const int _cols = 7;
const int _brickRows = 5;
const double _ballR = 0.018;
const double _paddleW = 0.22;
const double _paddleY = 0.93; // 패들 중심 y
const double _brickTop = 0.10;
const double _brickH = 0.045;

class _Ball {
  double x, y, vx, vy;
  bool stuck;
  double stuckDx; // 패들 중심 대비 상대 위치
  _Ball(this.x, this.y, this.vx, this.vy, {this.stuck = false, this.stuckDx = 0});
}

class _Drop {
  double x, y;
  final int type; // 0=x2데미지, 1=분열, 2=자석
  _Drop(this.x, this.y, this.type);
}

class _BreakoutGameState extends State<BreakoutGame> {
  final _rng = Random();
  final List<_Ball> _balls = [];
  final List<_Drop> _drops = [];
  // 시작 전에도 build가 _hp를 참조하므로 기본 빈 그리드로 초기화(late 크래시 방지)
  List<List<int>> _hp = List.generate(_brickRows, (_) => List.filled(_cols, 0));
  double _paddleX = 0.5;
  int _score = 0;
  int _doubleDmg = 0; // 잔여 프레임
  int _magnet = 0; // 잔여 프레임
  bool _running = false;
  Timer? _loop;

  int get _damage => _doubleDmg > 0 ? 2 : 1;

  void _start() {
    _hp = List.generate(_brickRows, (r) => List.generate(_cols, (c) => _brickRows - r > 3 ? 2 : 1));
    _balls.clear();
    _drops.clear();
    _paddleX = 0.5;
    _score = 0;
    _doubleDmg = 0;
    _magnet = 0;
    _balls.add(_Ball(0.5, _paddleY - _ballR - 0.01, 0, 0, stuck: true, stuckDx: 0));
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    setState(() {});
  }

  void _launch() {
    var any = false;
    for (final b in _balls) {
      if (b.stuck) {
        b.stuck = false;
        final dir = _rng.nextBool() ? 1 : -1;
        b.vx = 0.006 * dir;
        b.vy = -0.013;
        any = true;
      }
    }
    if (any) setState(() {});
  }

  void _tap() {
    if (!_running) {
      _start();
      return;
    }
    _launch();
  }

  void _movePaddle(double nx) {
    _paddleX = nx.clamp(_paddleW / 2, 1 - _paddleW / 2);
  }

  void _tick() {
    if (!_running) return;
    if (_doubleDmg > 0) _doubleDmg--;
    if (_magnet > 0) _magnet--;

    for (final b in _balls) {
      if (b.stuck) {
        b.x = _paddleX + b.stuckDx;
        continue;
      }
      b.x += b.vx;
      b.y += b.vy;
      // 좌우 벽
      if (b.x < _ballR) {
        b.x = _ballR;
        b.vx = b.vx.abs();
      } else if (b.x > 1 - _ballR) {
        b.x = 1 - _ballR;
        b.vx = -b.vx.abs();
      }
      // 천장
      if (b.y < _ballR) {
        b.y = _ballR;
        b.vy = b.vy.abs();
      }
      // 패들
      if (b.vy > 0 && b.y >= _paddleY - _ballR - 0.01 && b.y <= _paddleY + 0.02) {
        if ((b.x - _paddleX).abs() <= _paddleW / 2 + _ballR) {
          if (_magnet > 0) {
            b.stuck = true;
            b.stuckDx = (b.x - _paddleX).clamp(-_paddleW / 2, _paddleW / 2);
            b.vx = 0;
            b.vy = 0;
          } else {
            b.vy = -b.vy.abs();
            // 패들 위치에 따라 반사각 조절
            b.vx = ((b.x - _paddleX) / (_paddleW / 2)) * 0.011;
            b.y = _paddleY - _ballR - 0.01;
          }
        }
      }
      // 벽돌 충돌
      _hitBricks(b);
    }
    // 바닥으로 떨어진 공 제거
    _balls.removeWhere((b) => b.y > 1.02);
    if (_balls.isEmpty) {
      _end();
      return;
    }

    // 아이템 낙하
    for (final d in _drops) {
      d.y += 0.006;
    }
    _drops.removeWhere((d) {
      if (d.y >= _paddleY - 0.02 && (d.x - _paddleX).abs() <= _paddleW / 2 + 0.02) {
        _applyDrop(d.type);
        return true;
      }
      return d.y > 1.05;
    });

    // 전부 깼으면 새 판
    if (_hp.every((row) => row.every((v) => v == 0))) {
      _score += 100; // 클리어 보너스
      _hp = List.generate(_brickRows, (r) => List.generate(_cols, (c) => _brickRows - r > 3 ? 2 : 1));
    }

    setState(() {});
  }

  void _hitBricks(_Ball b) {
    for (var r = 0; r < _brickRows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_hp[r][c] == 0) continue;
        final left = c / _cols;
        final right = (c + 1) / _cols;
        final top = _brickTop + r * _brickH;
        final bottom = top + _brickH;
        if (b.x >= left - _ballR && b.x <= right + _ballR && b.y >= top - _ballR && b.y <= bottom + _ballR) {
          // 단순 반사: 위/아래에서 왔으면 vy, 옆에서 왔으면 vx 반전(근사)
          final fromSide = b.x < left || b.x > right;
          if (fromSide) {
            b.vx = -b.vx;
          } else {
            b.vy = -b.vy;
          }
          _hp[r][c] = max(0, _hp[r][c] - _damage);
          if (_hp[r][c] == 0) {
            _score += 10;
            // 25% 확률로 아이템 드랍
            if (_rng.nextInt(100) < 25) {
              _drops.add(_Drop((c + 0.5) / _cols, top, _rng.nextInt(3)));
            }
          }
          return; // 한 틱에 한 벽돌만
        }
      }
    }
  }

  void _applyDrop(int type) {
    if (type == 0) {
      _doubleDmg = 420; // 약 7초
    } else if (type == 1) {
      // 공 분열: 현재 움직이는 공마다 1개씩 추가
      final extra = <_Ball>[];
      for (final b in _balls) {
        if (!b.stuck) extra.add(_Ball(b.x, b.y, -b.vx, b.vy));
      }
      _balls.addAll(extra);
    } else {
      _magnet = 480; // 약 8초
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

  Color _brickColor(int r, int hp) => hp >= 2 ? const Color(0xFF5E35B1) : Color.lerp(const Color(0xFFEF5350), const Color(0xFF42A5F5), r / _brickRows)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('벽돌깨기 🧱   $_score${_doubleDmg > 0 ? '   💥x2' : ''}${_magnet > 0 ? '   🧲' : ''}')),
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          onPanUpdate: (d) => setState(() => _movePaddle(d.localPosition.dx / w)),
          child: Container(
            color: const Color(0xFF0D1B2A),
            child: Stack(
              children: [
                // 벽돌
                for (var r = 0; r < _brickRows; r++)
                  for (var c = 0; c < _cols; c++)
                    if (_hp[r][c] > 0)
                      Positioned(
                        left: c / _cols * w + 1.5,
                        top: (_brickTop + r * _brickH) * h + 1.5,
                        width: w / _cols - 3,
                        height: _brickH * h - 3,
                        child: Container(
                          decoration: BoxDecoration(color: _brickColor(r, _hp[r][c]), borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                // 아이템
                for (final d in _drops)
                  Positioned(
                    left: d.x * w - 14,
                    top: d.y * h - 14,
                    width: 28,
                    height: 28,
                    child: Center(child: Text(d.type == 0 ? '💥' : (d.type == 1 ? '➕' : '🧲'), style: const TextStyle(fontSize: 24))),
                  ),
                // 공
                for (final b in _balls)
                  Positioned(
                    left: b.x * w - _ballR * w,
                    top: b.y * h - _ballR * w,
                    width: _ballR * 2 * w,
                    height: _ballR * 2 * w,
                    child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                  ),
                // 패들
                Positioned(
                  left: (_paddleX - _paddleW / 2) * w,
                  top: _paddleY * h - 7,
                  width: _paddleW * w,
                  height: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _magnet > 0 ? const Color(0xFFFFCA28) : const Color(0xFF90CAF9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (!_running)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '게임 오버! 점수 $_score 🧱' : '드래그로 패들 이동, 탭해서 공 발사!\n💥x2데미지 · ➕공분열 · 🧲자석', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
