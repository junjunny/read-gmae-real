import 'dart:math';

import 'package:flutter/material.dart';

/// 2048: 밀어서 같은 숫자 합치기. 합쳐질 때마다 점수. 더 못 움직이면 게임오버.
class Game2048 extends StatefulWidget {
  final void Function(int score) onFinish;
  const Game2048({super.key, required this.onFinish});
  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  static const n = 4;
  late List<List<int>> _g;
  int _score = 0;
  bool _over = false;
  bool _started = false;
  final _rng = Random();

  void _start() {
    _g = List.generate(n, (_) => List.filled(n, 0));
    _score = 0;
    _over = false;
    _started = true;
    _spawn();
    _spawn();
    setState(() {});
  }

  void _spawn() {
    final empty = <List<int>>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (_g[r][c] == 0) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return;
    final p = empty[_rng.nextInt(empty.length)];
    _g[p[0]][p[1]] = _rng.nextInt(10) == 0 ? 4 : 2;
  }

  List<int> _merge(List<int> row) {
    var t = row.where((v) => v != 0).toList();
    for (var i = 0; i < t.length - 1; i++) {
      if (t[i] == t[i + 1]) {
        t[i] *= 2;
        _score += t[i];
        t[i + 1] = 0;
      }
    }
    t = t.where((v) => v != 0).toList();
    while (t.length < n) {
      t.add(0);
    }
    return t;
  }

  bool _eq(List<List<int>> a, List<List<int>> b) {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  void _move(int dir) {
    // dir: 0=left,1=right,2=up,3=down
    if (_over) return;
    final before = _g.map((r) => List<int>.from(r)).toList();
    var rows = <List<int>>[];
    if (dir == 0 || dir == 1) {
      for (var r = 0; r < n; r++) {
        var row = List<int>.from(_g[r]);
        if (dir == 1) row = row.reversed.toList();
        row = _merge(row);
        if (dir == 1) row = row.reversed.toList();
        rows.add(row);
      }
      _g = rows;
    } else {
      for (var c = 0; c < n; c++) {
        var col = [for (var r = 0; r < n; r++) _g[r][c]];
        if (dir == 3) col = col.reversed.toList();
        col = _merge(col);
        if (dir == 3) col = col.reversed.toList();
        for (var r = 0; r < n; r++) {
          _g[r][c] = col[r];
        }
      }
    }
    if (!_eq(before, _g)) {
      _spawn();
      if (!_canMove()) {
        _over = true;
        widget.onFinish(_score);
      }
    }
    setState(() {});
  }

  bool _canMove() {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (_g[r][c] == 0) return true;
        if (c < n - 1 && _g[r][c] == _g[r][c + 1]) return true;
        if (r < n - 1 && _g[r][c] == _g[r + 1][c]) return true;
      }
    }
    return false;
  }

  Color _tile(int v) {
    const m = {
      0: Color(0xFFCDC1B4), 2: Color(0xFFEEE4DA), 4: Color(0xFFEDE0C8), 8: Color(0xFFF2B179),
      16: Color(0xFFF59563), 32: Color(0xFFF67C5F), 64: Color(0xFFF65E3B), 128: Color(0xFFEDCF72),
      256: Color(0xFFEDCC61), 512: Color(0xFFEDC850), 1024: Color(0xFFEDC53F), 2048: Color(0xFFEDC22E),
    };
    return m[v] ?? const Color(0xFF3C3A32);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(title: Text('2048 🔢   점수 $_score')),
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
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFBBADA0), borderRadius: BorderRadius.circular(8)),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n, mainAxisSpacing: 6, crossAxisSpacing: 6),
                          itemCount: n * n,
                          itemBuilder: (_, i) {
                            final v = _g[i ~/ n][i % n];
                            final base = _tile(v);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                gradient: v == 0
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color.lerp(base, Colors.white, 0.22)!, base, Color.lerp(base, Colors.black, 0.10)!],
                                        stops: const [0.0, 0.55, 1.0],
                                      ),
                                color: v == 0 ? base : null,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: v == 0 ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 3, offset: const Offset(0, 2))],
                              ),
                              child: Center(child: Text(v == 0 ? '' : '$v', style: TextStyle(fontSize: v >= 1024 ? 18 : 24, fontWeight: FontWeight.bold, color: v <= 4 ? const Color(0xFF776E65) : Colors.white))),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
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

  Widget _btn(IconData i, VoidCallback f) => IconButton.filledTonal(onPressed: f, iconSize: 30, icon: Icon(i));
}
