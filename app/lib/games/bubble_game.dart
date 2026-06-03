import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

import 'game_fx.dart';

/// 버블슈터 🫧: 아래에서 버블을 쏴 같은 색 3개 이상을 터뜨린다.
/// 💣 폭탄 버블은 주변까지 한 번에! / 🌈 레인보우 버블은 어떤 색과도 매치!
/// 버블이 바닥까지 내려오면 게임 오버.
class BubbleGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const BubbleGame({super.key, required this.onFinish});
  @override
  State<BubbleGame> createState() => _BubbleGameState();
}

const int _cols = 9;
const double _cell = 1.0 / _cols;
const double _rad = _cell / 2;
const int _rainbow = 91; // 발사체 전용 특수(만능 매치)
const List<Color> _bubbleColors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
  Color(0xFFFDD835), Color(0xFF8E24AA), Color(0xFFFB8C00), // 6색(난이도 ↑)
];

class _BubbleGameState extends State<BubbleGame> {
  final _rng = Random();
  // 그리드: 색 인덱스(0~5), 빈칸 -1
  List<List<int>> _grid = [];
  int _maxRows = 14;
  double _h = 1.6; // 화면 세로(가로=1 기준)

  int _cur = 0; // 현재 발사 버블(색 또는 특수)
  int _nextBubble = 0;
  double _px = 0.5, _py = 1.5; // 발사체 위치
  double _vx = 0, _vy = 0;
  bool _flying = false;
  int _score = 0;
  int _shots = 0;
  int _sincePush = 0; // 마지막 줄 추가 이후 발사 횟수
  bool _running = false;
  Timer? _loop;

  // 조준(누르고 있는 동안 점선 궤적 표시 → 떼면 발사)
  double _aimX = 0.5, _aimY = 0;
  bool _aiming = false;

  void _aim(double tx, double ty) {
    if (!_running || _flying) return;
    _aimX = tx;
    _aimY = ty;
    _aiming = ty < (_h - _rad) - 0.02; // 위쪽을 향할 때만 궤적 표시
    setState(() {});
  }

  void _release() {
    if (_running && !_flying && _aiming) _shoot(_aimX, _aimY);
    _aiming = false;
    setState(() {});
  }

  void _start() {
    _grid = List.generate(_maxRows, (_) => List.filled(_cols, -1));
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < _cols; c++) {
        _grid[r][c] = _rng.nextInt(_bubbleColors.length);
      }
    }
    _score = 0;
    _shots = 0;
    _sincePush = 0;
    _flying = false;
    _cur = _newBubble();
    _nextBubble = _newBubble();
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    setState(() {});
  }

  int _newBubble() {
    final roll = _rng.nextInt(100);
    if (roll < 6) return _rainbow; // 🌈 만능 버블(빈도 ↓)
    // 보드에 남아있는 색 위주로
    final present = <int>{};
    for (final row in _grid) {
      for (final v in row) {
        if (v >= 0 && v < _bubbleColors.length) present.add(v);
      }
    }
    if (present.isEmpty) return _rng.nextInt(_bubbleColors.length);
    final list = present.toList();
    return list[_rng.nextInt(list.length)];
  }

  void _shoot(double tx, double ty) {
    if (!_running || _flying) return;
    final dx = tx - 0.5;
    final dy = ty - (_h - _rad);
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001 || dy > -0.02) return; // 위쪽으로만
    const speed = 0.03;
    _vx = dx / len * speed;
    _vy = dy / len * speed;
    _px = 0.5;
    _py = _h - _rad;
    _flying = true;
  }

  void _tick() {
    if (!_running || !_flying) return;
    _px += _vx;
    _py += _vy;
    if (_px < _rad) {
      _px = _rad;
      _vx = _vx.abs();
    } else if (_px > 1 - _rad) {
      _px = 1 - _rad;
      _vx = -_vx.abs();
    }
    // 천장 또는 버블 충돌 → 스냅
    var hit = _py <= _rad;
    if (!hit) {
      for (var r = 0; r < _maxRows && !hit; r++) {
        for (var c = 0; c < _cols; c++) {
          if (_grid[r][c] == -1) continue;
          final cx = (c + 0.5) * _cell, cy = (r + 0.5) * _cell;
          final dist = sqrt(pow(_px - cx, 2) + pow(_py - cy, 2));
          if (dist < 2 * _rad * 0.9) {
            hit = true;
            break;
          }
        }
      }
    }
    if (hit) {
      _attach();
    }
    setState(() {});
  }

  void _attach() {
    _flying = false;
    // 가장 가까운 빈 셀 찾기
    var col = (_px / _cell - 0.5).round().clamp(0, _cols - 1);
    var row = (_py / _cell - 0.5).round().clamp(0, _maxRows - 1);
    if (_grid[row][col] != -1) {
      final cell = _nearestEmpty(row, col);
      if (cell == null) {
        _end();
        return;
      }
      row = cell[0];
      col = cell[1];
    }

    final shot = _cur;
    if (shot == _rainbow) {
      // 🌈 만능 버블: 닿는 모든 색의 연결 그룹을 통째로 터뜨린다(색 구분 없이 상호작용).
      final remove = <String>{};
      for (final nb in _around8(row, col)) {
        final v = _grid[nb[0]][nb[1]];
        if (v >= 0) {
          for (final p in _flood(nb[0], nb[1], v)) {
            remove.add('${p[0]},${p[1]}');
          }
        }
      }
      for (final key in remove) {
        final parts = key.split(',');
        _grid[int.parse(parts[0])][int.parse(parts[1])] = -1;
      }
      _grid[row][col] = -1; // 레인보우 자체는 사라짐
      _score += (remove.length + 1) * 10;
      if (remove.isNotEmpty) _dropFloating();
    } else {
      _grid[row][col] = shot;
      if (row >= _maxRows - 1) {
        // 바닥 도달
        _end();
        return;
      }
      final group = _flood(row, col, shot);
      if (group.length >= 3) {
        for (final p in group) {
          _grid[p[0]][p[1]] = -1;
        }
        _score += group.length * 10;
        _dropFloating();
      }
    }

    _shots++;
    _sincePush++;
    // 점진적 압박: 처음엔 5발마다, 진행될수록 더 자주 한 줄 내려온다.
    final interval = _shots > 60 ? 3 : (_shots > 30 ? 4 : 5);
    if (_sincePush >= interval) {
      _sincePush = 0;
      _pushDownRow();
    }

    _cur = _nextBubble;
    _nextBubble = _newBubble();
    setState(() {});
  }

  List<int>? _nearestEmpty(int row, int col) {
    for (var rad = 1; rad < 5; rad++) {
      for (var dr = -rad; dr <= rad; dr++) {
        for (var dc = -rad; dc <= rad; dc++) {
          final nr = row + dr, nc = col + dc;
          if (nr >= 0 && nr < _maxRows && nc >= 0 && nc < _cols && _grid[nr][nc] == -1) {
            return [nr, nc];
          }
        }
      }
    }
    return null;
  }

  // 인접(대각선 포함 8방향) — 사각 격자라 대각선으로 닿은 같은 색이
  // 안 터지던(씹히던) 문제를 해결한다. 매치·천장연결성 모두 동일 기준 사용.
  List<List<int>> _around8(int r, int c) {
    final res = <List<int>>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < _maxRows && nc >= 0 && nc < _cols) res.add([nr, nc]);
      }
    }
    return res;
  }

  // 같은 색 연결 그룹(대각선 포함 8방향)
  List<List<int>> _flood(int r, int c, int color) {
    final seen = <String>{};
    final stack = [[r, c]];
    final res = <List<int>>[];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = '${p[0]},${p[1]}';
      if (seen.contains(key)) continue;
      seen.add(key);
      if (_grid[p[0]][p[1]] != color) continue;
      res.add(p);
      stack.addAll(_around8(p[0], p[1]));
    }
    return res;
  }

  // 천장에 연결 안 된 떠있는 버블 제거
  void _dropFloating() {
    final connected = <String>{};
    final stack = <List<int>>[];
    for (var c = 0; c < _cols; c++) {
      if (_grid[0][c] != -1) stack.add([0, c]);
    }
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = '${p[0]},${p[1]}';
      if (connected.contains(key)) continue;
      if (_grid[p[0]][p[1]] == -1) continue;
      connected.add(key);
      stack.addAll(_around8(p[0], p[1])); // 매치와 동일하게 8방향 연결성
    }
    var dropped = 0;
    for (var r = 0; r < _maxRows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != -1 && !connected.contains('$r,$c')) {
          _grid[r][c] = -1;
          dropped++;
        }
      }
    }
    if (dropped > 0) _score += dropped * 15;
  }

  void _pushDownRow() {
    // 맨 아래 줄에 버블이 있으면 게임 오버
    if (_grid[_maxRows - 1].any((v) => v != -1)) {
      _end();
      return;
    }
    for (var r = _maxRows - 1; r > 0; r--) {
      _grid[r] = List.from(_grid[r - 1]);
    }
    _grid[0] = List.generate(_cols, (_) => _rng.nextInt(_bubbleColors.length));
  }

  void _end() {
    _running = false;
    _flying = false;
    _loop?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  // 부드럽고 광택 있는 버블
  Widget _bubbleDot(int v, double size) {
    if (v == _rainbow) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835),
            Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFE53935),
          ]),
          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: _gloss(),
      );
    }
    final Color base = _bubbleColors[v];
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.42),
          radius: 0.95,
          colors: [
            Color.lerp(base, Colors.white, 0.6)!,
            base,
            Color.lerp(base, Colors.black, 0.22)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: _gloss(),
    );
  }

  // 좌상단 광택 하이라이트
  Widget _gloss() => const Align(
        alignment: Alignment(-0.4, -0.45),
        child: FractionallySizedBox(
          widthFactor: 0.34,
          heightFactor: 0.34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.white, Color(0x11FFFFFF)]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: GameTitle('🫧  $_score')),
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        _h = h / w; // 가로=1 기준 세로 길이
        _maxRows = (_h / _cell).floor();
        if (_running && _grid.length < _maxRows) {
          // 화면이 커지면 행 보강
          while (_grid.length < _maxRows) {
            _grid.add(List.filled(_cols, -1));
          }
        }
        final dotPx = _cell * w;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _aim(e.localPosition.dx / w, e.localPosition.dy / w),
          onPointerMove: (e) => _aim(e.localPosition.dx / w, e.localPosition.dy / w),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B3A5B), Color(0xFF0B1B2E)],
              ),
            ),
            child: Stack(
              children: [
                // 그리드 버블
                for (var r = 0; r < _grid.length; r++)
                  for (var c = 0; c < _cols; c++)
                    if (_grid[r][c] != -1 && _grid[r][c] != -2)
                      Positioned(
                        left: c * dotPx + 1,
                        top: r * dotPx + 1,
                        width: dotPx - 2,
                        height: dotPx - 2,
                        child: _bubbleDot(_grid[r][c], dotPx),
                      ),
                // 조준 점선 궤적(벽 반사 예측)
                if (_running && _aiming && !_flying)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _AimPainter(
                          grid: _grid,
                          maxRows: _maxRows,
                          aimX: _aimX,
                          aimY: _aimY,
                          h: _h,
                          w: w,
                        ),
                      ),
                    ),
                  ),
                // 발사체
                if (_flying)
                  Positioned(
                    left: (_px - _rad) * w + 1,
                    top: (_py - _rad) * w + 1,
                    width: dotPx - 2,
                    height: dotPx - 2,
                    child: _bubbleDot(_cur, dotPx),
                  ),
                // 발사 대기 버블(바닥 중앙)
                if (_running && !_flying)
                  Positioned(
                    left: 0.5 * w - dotPx / 2 + 1,
                    top: (_h - _rad) * w - dotPx / 2,
                    width: dotPx - 2,
                    height: dotPx - 2,
                    child: _bubbleDot(_cur, dotPx),
                  ),
                // 다음 버블 안내
                if (_running)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        const Text('다음 ', style: TextStyle(color: Colors.white70)),
                        SizedBox(width: dotPx, height: dotPx, child: _bubbleDot(_nextBubble, dotPx)),
                      ],
                    ),
                  ),
                if (!_running)
                  Center(
                    child: PopPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '게임 오버! 점수 $_score 🫧' : '누른 방향으로 조준(점선) → 떼면 발사!\n같은 색 3개+ 매치 · 🌈레인보우는 닿는 색 다 터뜨림!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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

/// 조준 궤적(점선): 발사 시작점에서 조준 방향으로 벽 반사를 예측해 점을 찍는다.
/// 게임 좌표(가로=1 기준) → 픽셀은 값 × w.
class _AimPainter extends CustomPainter {
  final List<List<int>> grid;
  final int maxRows;
  final double aimX, aimY, h, w;
  _AimPainter({
    required this.grid,
    required this.maxRows,
    required this.aimX,
    required this.aimY,
    required this.h,
    required this.w,
  });

  static const int _cols = 9;
  static const double _cell = 1.0 / _cols;
  static const double _rad = _cell / 2;

  bool _hits(double px, double py) {
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < _cols; c++) {
        if (grid[r][c] == -1) continue;
        final cx = (c + 0.5) * _cell, cy = (r + 0.5) * _cell;
        final dx = px - cx, dy = py - cy;
        if (dx * dx + dy * dy < pow(2 * _rad * 0.9, 2)) return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final startY = h - _rad;
    var dx = aimX - 0.5, dy = aimY - startY;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001 || dy > -0.02) return;
    dx /= len;
    dy /= len;
    var px = 0.5, py = startY;
    const step = 0.01;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 700; i++) {
      px += dx * step;
      py += dy * step;
      if (px < _rad) {
        px = _rad;
        dx = dx.abs();
      } else if (px > 1 - _rad) {
        px = 1 - _rad;
        dx = -dx.abs();
      }
      if (py <= _rad) break; // 천장
      if (_hits(px, py)) break; // 버블에 닿으면 멈춤
      if (i % 4 == 0) canvas.drawCircle(Offset(px * w, py * w), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _AimPainter old) =>
      old.aimX != aimX || old.aimY != aimY || old.grid != grid;
}
