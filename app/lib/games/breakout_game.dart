import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

import 'game_fx.dart';

/// 벽돌깨기 🧱: 패들을 좌우로 움직여 공을 튕겨 벽돌을 부순다.
/// 떨어지는 아이템: 💥 x2 데미지 / ➕ 공 분열(2개) / 🧲 자석 패들(공이 붙었다 탭하면 발사).
class BreakoutGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const BreakoutGame({super.key, required this.onFinish});
  @override
  State<BreakoutGame> createState() => _BreakoutGameState();
}

const int _cols = 9;
const int _brickRows = 10;
const double _ballR = 0.017;
const double _paddleW = 0.22;
const double _paddleY = 0.93; // 패들 중심 y
const double _brickTop = 0.07;
const double _brickH = 0.038;

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
  int _level = 1;
  int _lives = 3;
  int _doubleDmg = 0; // 잔여 프레임
  int _magnet = 0; // 잔여 프레임
  bool _running = false;
  String? _fx; // 레벨업 배너
  Timer? _loop, _fxTimer;

  int get _damage => _doubleDmg > 0 ? 2 : 1;
  // 레벨이 오를수록 공이 빨라짐
  double get _spd => 0.012 * (1 + (_level - 1) * 0.10);

  // 레벨별 맵: 패턴 6종을 돌면서, 한 바퀴마다 내구도(tier) +1.
  List<List<int>> _buildMap(int level) {
    final pattern = (level - 1) % 6;
    final tier = (level - 1) ~/ 6;
    return List.generate(_brickRows, (r) {
      return List.generate(_cols, (c) {
        bool fill;
        switch (pattern) {
          case 0:
            fill = true; // 가득
            break;
          case 1:
            fill = (r + c) % 2 == 0; // 체커보드
            break;
          case 2:
            fill = c % 2 == 0; // 세로 기둥
            break;
          case 3:
            fill = r % 2 == 0; // 가로 줄
            break;
          case 4:
            fill = r == 0 || r == _brickRows - 1 || c == 0 || c == _cols - 1 || c == _cols ~/ 2; // 프레임+중앙기둥
            break;
          default:
            fill = ((r - _brickRows ~/ 2).abs() + (c - _cols ~/ 2).abs()) <= 4; // 다이아몬드
            break;
        }
        if (!fill) return 0;
        final hp = 1 + (r < 3 ? 1 : 0) + tier;
        return hp > 4 ? 4 : hp;
      });
    });
  }

  void _flashLevel() {
    _fx = '레벨 $_level! 🚀';
    _fxTimer?.cancel();
    _fxTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _fx = null);
    });
  }

  // 패들 위에 멈춘 새 공
  void _spawnStuckBall() {
    _balls.add(_Ball(_paddleX, _paddleY - _ballR - 0.01, 0, 0, stuck: true, stuckDx: 0));
  }

  void _start() {
    _level = 1;
    _lives = 3;
    _hp = _buildMap(_level);
    _balls.clear();
    _drops.clear();
    _paddleX = 0.5;
    _score = 0;
    _doubleDmg = 0;
    _magnet = 0;
    _fx = null;
    _spawnStuckBall();
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
        b.vx = _spd * 0.5 * dir;
        b.vy = -_spd;
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
            b.vy = -_spd; // 레벨 속도 유지
            // 패들 위치에 따라 반사각 조절
            b.vx = ((b.x - _paddleX) / (_paddleW / 2)) * _spd * 0.85;
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
      _lives--;
      if (_lives <= 0) {
        _end();
        return;
      }
      // 목숨 차감 후 패들에 새 공(효과 초기화)
      _doubleDmg = 0;
      _magnet = 0;
      _drops.clear();
      _spawnStuckBall();
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

    // 전부 깼으면 다음 레벨(새 맵 + 클리어 보너스 + 더 빠른 공)
    if (_hp.every((row) => row.every((v) => v == 0))) {
      _score += 100 * _level; // 레벨 비례 클리어 보너스
      _level++;
      _hp = _buildMap(_level);
      _balls.clear();
      _drops.clear();
      _doubleDmg = 0;
      _magnet = 0;
      _spawnStuckBall(); // 다음 레벨은 탭해서 발사
      _flashLevel();
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
            // 레벨이 오를수록 아이템 드랍 확률 감소(25%→최소 8%)
            if (_rng.nextInt(100) < max(8, 25 - _level * 2)) {
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
    _fxTimer?.cancel();
    super.dispose();
  }

  Color _brickColor(int r, int hp) {
    switch (hp) {
      case 1:
        return Color.lerp(const Color(0xFFEF5350), const Color(0xFF42A5F5), r / _brickRows)!;
      case 2:
        return const Color(0xFF5E35B1);
      case 3:
        return const Color(0xFFFB8C00);
      default:
        return const Color(0xFFB71C1C); // 4HP
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: GameTitle('🧱  Lv$_level  ${'❤️' * _lives}  $_score${_doubleDmg > 0 ? ' 💥x2' : ''}${_magnet > 0 ? ' 🧲' : ''}')),
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          onPanUpdate: (d) => setState(() => _movePaddle(d.localPosition.dx / w)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B2D45), Color(0xFF09111E)],
              ),
            ),
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
                        child: Builder(builder: (_) {
                          final bc = _brickColor(r, _hp[r][c]);
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color.lerp(bc, Colors.white, 0.35)!, bc, Color.lerp(bc, Colors.black, 0.16)!],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, 1))],
                            ),
                          );
                        }),
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
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          colors: [Colors.white, Color(0xFFB0BEC5)],
                        ),
                        boxShadow: [BoxShadow(color: Color(0x66FFFFFF), blurRadius: 6, spreadRadius: 1)],
                      ),
                    ),
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
                // 레벨업 배너
                if (_fx != null)
                  Center(
                    child: Text(_fx!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFFFD54F))),
                  ),
                if (!_running)
                  Center(
                    child: PopPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '게임 오버! 레벨 $_level · 점수 $_score 🧱' : '드래그로 패들 이동, 탭해서 발사!\n맵을 다 깨면 다음 레벨(점점 빨라짐)\n목숨 ❤️3 · 💥x2 · ➕분열 · 🧲자석', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
