import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 블록 블라스트 🟦: 아래 3개 조각 중 하나를 골라(탭) 보드에 놓아(탭) 줄(가로·세로)을 채운다.
/// 줄이 가득 차면 제거 + 점수! 🔥 2줄 이상 동시 제거 시 x1.5 불꽃 보너스 / 🌟 와일드 블록은 가로·세로를 통째로 제거.
class BlastGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const BlastGame({super.key, required this.onFinish});
  @override
  State<BlastGame> createState() => _BlastGameState();
}

const int _n = 8;

const List<List<List<int>>> _shapes = [
  [[0, 0]],
  [[0, 0], [0, 1]],
  [[0, 0], [0, 1], [0, 2]],
  [[0, 0], [0, 1], [0, 2], [0, 3]],
  [[0, 0], [1, 0]],
  [[0, 0], [1, 0], [2, 0]],
  [[0, 0], [1, 0], [2, 0], [3, 0]],
  [[0, 0], [0, 1], [1, 0], [1, 1]],
  [[0, 0], [1, 0], [1, 1]],
  [[0, 1], [1, 0], [1, 1]],
  [[0, 0], [0, 1], [1, 1]],
  [[0, 0], [0, 1], [1, 0]],
  [[0, 0], [0, 1], [0, 2], [1, 1]],
];

const List<Color> _pieceColors = [
  Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFFFFA726), Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF26C6DA),
];

class _Piece {
  final List<List<int>> cells;
  final int color;
  final bool wild;
  _Piece(this.cells, this.color, {this.wild = false});
}

class _BlastGameState extends State<BlastGame> {
  final _rng = Random();
  late List<List<int>> _grid; // -1 빈칸, 0~ 색, 99 와일드
  List<_Piece?> _tray = [null, null, null];
  int _sel = -1;
  int _score = 0;
  bool _running = false;
  bool _flash = false;
  String? _fx;

  void _start() {
    _grid = List.generate(_n, (_) => List.filled(_n, -1));
    _score = 0;
    _sel = -1;
    _flash = false;
    _fx = null;
    _refillTray();
    _running = true;
    setState(() {});
  }

  _Piece _randomPiece() {
    if (_rng.nextInt(100) < 8) {
      return _Piece(const [[0, 0]], 0, wild: true); // 🌟 와일드
    }
    final s = _shapes[_rng.nextInt(_shapes.length)];
    return _Piece(s, _rng.nextInt(_pieceColors.length));
  }

  void _refillTray() {
    _tray = [_randomPiece(), _randomPiece(), _randomPiece()];
    _sel = _tray.indexWhere((p) => p != null);
  }

  bool _canPlace(_Piece p, int row, int col) {
    for (final cell in p.cells) {
      final r = row + cell[0], c = col + cell[1];
      if (r < 0 || r >= _n || c < 0 || c >= _n) return false;
      if (_grid[r][c] != -1) return false;
    }
    return true;
  }

  bool _anyMovePossible() {
    for (final p in _tray) {
      if (p == null) continue;
      for (var r = 0; r < _n; r++) {
        for (var c = 0; c < _n; c++) {
          if (_canPlace(p, r, c)) return true;
        }
      }
    }
    return false;
  }

  void _placeAt(int row, int col) {
    if (!_running || _sel < 0) return;
    final p = _tray[_sel];
    if (p == null || !_canPlace(p, row, col)) return;
    final code = p.wild ? 99 : p.color;
    var placed = 0;
    for (final cell in p.cells) {
      _grid[row + cell[0]][col + cell[1]] = code;
      placed++;
    }
    _score += placed;
    _tray[_sel] = null;

    // 와일드: 놓인 칸의 가로·세로 줄을 통째로 제거
    if (p.wild) {
      for (var c = 0; c < _n; c++) {
        _grid[row][c] = -1;
      }
      for (var r = 0; r < _n; r++) {
        _grid[r][col] = -1;
      }
      _score += 50;
      _fx = '🌟 와일드!';
      Timer(const Duration(milliseconds: 700), () => mounted ? setState(() => _fx = null) : null);
    }

    _clearLines();

    // 트레이 비었으면 리필
    if (_tray.every((e) => e == null)) {
      _refillTray();
    } else {
      _sel = _tray.indexWhere((e) => e != null);
    }

    if (!_anyMovePossible()) {
      _end();
      return;
    }
    setState(() {});
  }

  void _clearLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (var r = 0; r < _n; r++) {
      if (_grid[r].every((v) => v != -1)) fullRows.add(r);
    }
    for (var c = 0; c < _n; c++) {
      if (List.generate(_n, (r) => _grid[r][c]).every((v) => v != -1)) fullCols.add(c);
    }
    final lines = fullRows.length + fullCols.length;
    if (lines == 0) return;
    for (final r in fullRows) {
      for (var c = 0; c < _n; c++) {
        _grid[r][c] = -1;
      }
    }
    for (final c in fullCols) {
      for (var r = 0; r < _n; r++) {
        _grid[r][c] = -1;
      }
    }
    var bonus = lines * 100;
    if (lines >= 2) {
      bonus = (bonus * 1.5).round(); // 🔥 동시 제거 x1.5
      _flash = true;
      _fx = '🔥 $lines줄 동시! x1.5';
      Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _flash = false;
            _fx = null;
          });
        }
      });
    }
    _score += bonus;
  }

  void _end() {
    _running = false;
    setState(() {});
    widget.onFinish(_score);
  }

  Color _cellColor(int v) => v == 99 ? const Color(0xFFFFD54F) : _pieceColors[v];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('블록 블라스트 🟦   $_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '게임 오버! 점수 $_score 🟦' : '조각을 골라(탭) 보드에 놓아(탭)\n줄을 채워 터뜨리세요!\n🔥2줄 동시 x1.5 · 🌟와일드', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : Column(
              children: [
                if (_fx != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_fx!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6F00))),
                  ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _flash ? const Color(0xFFFFE0B2) : const Color(0xFF263238),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _n, mainAxisSpacing: 2, crossAxisSpacing: 2),
                            itemCount: _n * _n,
                            itemBuilder: (_, i) {
                              final r = i ~/ _n, c = i % _n;
                              final v = _grid[r][c];
                              return GestureDetector(
                                onTap: () => _placeAt(r, c),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: v == -1 ? const Color(0xFF37474F) : _cellColor(v),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text('조각을 고른 뒤 보드를 탭하세요', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (i) => _traySlot(i)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _traySlot(int i) {
    final p = _tray[i];
    final selected = _sel == i;
    return GestureDetector(
      onTap: p == null ? null : () => setState(() => _sel = i),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F2FD) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300, width: selected ? 2.5 : 1),
        ),
        child: p == null ? const SizedBox() : _piecePreview(p),
      ),
    );
  }

  Widget _piecePreview(_Piece p) {
    var maxR = 0, maxC = 0;
    for (final cell in p.cells) {
      maxR = max(maxR, cell[0]);
      maxC = max(maxC, cell[1]);
    }
    const unit = 18.0;
    final cells = {for (final c in p.cells) '${c[0]},${c[1]}'};
    return Center(
      child: SizedBox(
        width: (maxC + 1) * unit,
        height: (maxR + 1) * unit,
        child: Stack(
          children: [
            for (var r = 0; r <= maxR; r++)
              for (var c = 0; c <= maxC; c++)
                if (cells.contains('$r,$c'))
                  Positioned(
                    left: c * unit,
                    top: r * unit,
                    width: unit - 2,
                    height: unit - 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.wild ? const Color(0xFFFFD54F) : _pieceColors[p.color],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: p.wild ? const Center(child: Text('🌟', style: TextStyle(fontSize: 11))) : null,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
