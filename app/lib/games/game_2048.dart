import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

/// 2048: 밀어서 같은 숫자 합치기. 합쳐질 때마다 점수. 더 못 움직이면 게임오버.
/// 타일이 실제로 미끄러지고(슬라이드) 생성·합체 시 살짝 팝(부드러운 애니메이션).
class Game2048 extends StatefulWidget {
  final void Function(int score) onFinish;
  const Game2048({super.key, required this.onFinish});
  @override
  State<Game2048> createState() => _Game2048State();
}

const int _n = 4;

class _Tile {
  final int id;
  int value;
  int r, c;
  double scale = 0.1; // 생성 시 작게 → 팝 인
  _Tile(this.id, this.value, this.r, this.c);
}

class _Game2048State extends State<Game2048> {
  final List<_Tile> _tiles = [];
  int _nextId = 0;
  int _score = 0;
  bool _over = false;
  bool _started = false;
  bool _busy = false; // 애니메이션 중 입력 무시
  final _rng = Random();
  Timer? _settle;

  void _start() {
    _tiles.clear();
    _nextId = 0;
    _score = 0;
    _over = false;
    _started = true;
    _busy = false;
    _spawn();
    _spawn();
    setState(() {});
    _scheduleSettle();
  }

  void _spawn() {
    final occupied = {for (final t in _tiles) t.r * _n + t.c};
    final empty = <List<int>>[];
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (!occupied.contains(r * _n + c)) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return;
    final p = empty[_rng.nextInt(empty.length)];
    _tiles.add(_Tile(_nextId++, _rng.nextInt(10) == 0 ? 4 : 2, p[0], p[1]));
  }

  // 생성/합체 직후의 팝 스케일을 잠시 뒤 1.0으로 되돌려 부드럽게 안착.
  void _scheduleSettle() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      for (final t in _tiles) {
        t.scale = 1.0;
      }
      setState(() {});
    });
  }

  List<int> _pos(int line, int idx, int dir) {
    switch (dir) {
      case 0:
        return [line, idx]; // left
      case 1:
        return [line, _n - 1 - idx]; // right
      case 2:
        return [idx, line]; // up
      default:
        return [_n - 1 - idx, line]; // down
    }
  }

  void _move(int dir) {
    if (_over || _busy || !_started) return;
    final removed = <_Tile>[];
    final doubled = <_Tile>[];
    var moved = false;
    var gained = 0;

    for (var line = 0; line < _n; line++) {
      // 이 줄의 타일을 이동 방향 앞쪽부터 정렬
      final ts = _tiles.where((t) => (dir == 0 || dir == 1) ? t.r == line : t.c == line).toList();
      ts.sort((a, b) {
        switch (dir) {
          case 0:
            return a.c - b.c;
          case 1:
            return b.c - a.c;
          case 2:
            return a.r - b.r;
          default:
            return b.r - a.r;
        }
      });

      var target = 0;
      var lastIndex = -1;
      var lastValue = -1;
      _Tile? lastTile;
      var mergeable = false;
      for (final tile in ts) {
        if (mergeable && lastValue == tile.value) {
          final p = _pos(line, lastIndex, dir); // 합쳐질 타일 위로 슬라이드
          tile.r = p[0];
          tile.c = p[1];
          removed.add(tile);
          doubled.add(lastTile!);
          gained += lastValue * 2;
          moved = true;
          mergeable = false;
        } else {
          final p = _pos(line, target, dir);
          if (tile.r != p[0] || tile.c != p[1]) moved = true;
          tile.r = p[0];
          tile.c = p[1];
          lastIndex = target;
          lastValue = tile.value;
          lastTile = tile;
          mergeable = true;
          target++;
        }
      }
    }

    if (!moved) return;

    // 1단계: 슬라이드(값은 그대로 → 합쳐지는 타일이 위로 미끄러져 들어감)
    _busy = true;
    setState(() {});

    // 2단계: 슬라이드 끝나면 합체 적용 + 새 타일 생성
    Timer(const Duration(milliseconds: 130), () {
      if (!mounted) return;
      for (final t in removed) {
        _tiles.remove(t);
      }
      for (final t in doubled) {
        t.value *= 2; // 합체는 팝 없이 값만 갱신(부드럽게)
      }
      _score += gained;
      _spawn();
      _busy = false;
      if (!_canMove()) {
        _over = true;
        widget.onFinish(_score);
      }
      setState(() {});
      _scheduleSettle();
    });
  }

  bool _canMove() {
    final g = List.generate(_n, (_) => List.filled(_n, 0));
    for (final t in _tiles) {
      g[t.r][t.c] = t.value;
    }
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (g[r][c] == 0) return true;
        if (c < _n - 1 && g[r][c] == g[r][c + 1]) return true;
        if (r < _n - 1 && g[r][c] == g[r + 1][c]) return true;
      }
    }
    return false;
  }

  Color _tile(int v) {
    const m = {
      2: Color(0xFFEEE4DA), 4: Color(0xFFEDE0C8), 8: Color(0xFFF2B179),
      16: Color(0xFFF59563), 32: Color(0xFFF67C5F), 64: Color(0xFFF65E3B), 128: Color(0xFFEDCF72),
      256: Color(0xFFEDCC61), 512: Color(0xFFEDC850), 1024: Color(0xFFEDC53F), 2048: Color(0xFFEDC22E),
    };
    return m[v] ?? const Color(0xFF3C3A32);
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(title: GameTitle('🔢  점수 $_score')),
      body: !_started || _over
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_over ? '게임 오버! 점수 $_score 🎉' : '밀어서 같은 숫자를 합쳐\n2048을 만들어보세요!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_over ? '다시' : '시작')),
              ]),
            )
          : GestureDetector(
              onPanEnd: (d) {
                final vx = d.velocity.pixelsPerSecond.dx, vy = d.velocity.pixelsPerSecond.dy;
                if (vx.abs() > vy.abs()) {
                  _move(vx > 0 ? 1 : 0);
                } else {
                  _move(vy > 0 ? 3 : 2);
                }
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(aspectRatio: 1, child: _board()),
                ),
              ),
            ),
      bottomNavigationBar: (_started && !_over)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _btn(Icons.arrow_left, () => _move(0)),
                    _btn(Icons.arrow_drop_up, () => _move(2)),
                    _btn(Icons.arrow_drop_down, () => _move(3)),
                    _btn(Icons.arrow_right, () => _move(1)),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _board() {
    return LayoutBuilder(builder: (_, bc) {
      final s = min(bc.maxWidth, bc.maxHeight);
      const pad = 6.0, gap = 6.0;
      final cell = (s - pad * 2 - gap * (_n - 1)) / _n;
      double left(int c) => pad + c * (cell + gap);
      double top(int r) => pad + r * (cell + gap);

      final children = <Widget>[];
      // 빈 칸(배경)
      for (var r = 0; r < _n; r++) {
        for (var c = 0; c < _n; c++) {
          children.add(Positioned(
            left: left(c),
            top: top(r),
            width: cell,
            height: cell,
            child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFCDC1B4), borderRadius: BorderRadius.circular(7))),
          ));
        }
      }
      // 타일(슬라이드 + 팝) — id 순으로 그려 위젯 매칭 안정화
      final tiles = [..._tiles]..sort((a, b) => a.id - b.id);
      for (final t in tiles) {
        children.add(AnimatedPositioned(
          key: ValueKey(t.id),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          left: left(t.c),
          top: top(t.r),
          width: cell,
          height: cell,
          child: AnimatedScale(
            scale: t.scale,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut, // 튕김(팝) 없이 부드럽게만
            child: _tileBox(t.value, cell),
          ),
        ));
      }

      return Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(color: const Color(0xFFBBADA0), borderRadius: BorderRadius.circular(8)),
        child: Stack(children: children),
      );
    });
  }

  Widget _tileBox(int v, double cell) {
    final base = _tile(v);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.22)!, base, Color.lerp(base, Colors.black, 0.10)!],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 3, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text('$v',
            style: TextStyle(
              fontSize: (v >= 1024 ? cell * 0.30 : cell * 0.42),
              fontWeight: FontWeight.bold,
              color: v <= 4 ? const Color(0xFF776E65) : Colors.white,
            )),
      ),
    );
  }

  Widget _btn(IconData i, VoidCallback f) => IconButton.filledTonal(onPressed: f, iconSize: 30, icon: Icon(i));
}
