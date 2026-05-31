import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 간단한 테트리스. 줄을 지우면 점수 획득. 게임 오버 시 onFinish(score).
class TetrisGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const TetrisGame({super.key, required this.onFinish});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

const int _cols = 10;
const int _rows = 18;

// 7 테트로미노 (회전 상태별 셀 좌표)
const List<List<List<List<int>>>> _shapes = [
  // I
  [
    [[0, 1], [1, 1], [2, 1], [3, 1]],
    [[2, 0], [2, 1], [2, 2], [2, 3]],
    [[0, 2], [1, 2], [2, 2], [3, 2]],
    [[1, 0], [1, 1], [1, 2], [1, 3]],
  ],
  // O
  [
    [[1, 0], [2, 0], [1, 1], [2, 1]],
    [[1, 0], [2, 0], [1, 1], [2, 1]],
    [[1, 0], [2, 0], [1, 1], [2, 1]],
    [[1, 0], [2, 0], [1, 1], [2, 1]],
  ],
  // T
  [
    [[1, 0], [0, 1], [1, 1], [2, 1]],
    [[1, 0], [1, 1], [2, 1], [1, 2]],
    [[0, 1], [1, 1], [2, 1], [1, 2]],
    [[1, 0], [0, 1], [1, 1], [1, 2]],
  ],
  // S
  [
    [[1, 0], [2, 0], [0, 1], [1, 1]],
    [[1, 0], [1, 1], [2, 1], [2, 2]],
    [[1, 1], [2, 1], [0, 2], [1, 2]],
    [[0, 0], [0, 1], [1, 1], [1, 2]],
  ],
  // Z
  [
    [[0, 0], [1, 0], [1, 1], [2, 1]],
    [[2, 0], [1, 1], [2, 1], [1, 2]],
    [[0, 1], [1, 1], [1, 2], [2, 2]],
    [[1, 0], [0, 1], [1, 1], [0, 2]],
  ],
  // J
  [
    [[0, 0], [0, 1], [1, 1], [2, 1]],
    [[1, 0], [2, 0], [1, 1], [1, 2]],
    [[0, 1], [1, 1], [2, 1], [2, 2]],
    [[1, 0], [1, 1], [0, 2], [1, 2]],
  ],
  // L
  [
    [[2, 0], [0, 1], [1, 1], [2, 1]],
    [[1, 0], [1, 1], [1, 2], [2, 2]],
    [[0, 1], [1, 1], [2, 1], [0, 2]],
    [[0, 0], [1, 0], [1, 1], [1, 2]],
  ],
];

const List<Color> _colors = [
  Color(0xFF4DD0E1), Color(0xFFFFD54F), Color(0xFFBA68C8), Color(0xFF81C784),
  Color(0xFFE57373), Color(0xFF64B5F6), Color(0xFFFFB74D),
];

class _TetrisGameState extends State<TetrisGame> {
  List<List<int>> _grid = List.generate(_rows, (_) => List.filled(_cols, -1)); // -1 빈칸, 0~6 색
  int _piece = 0, _rot = 0, _px = 3, _py = 0;
  int _score = 0;
  bool _running = false;
  Timer? _timer;
  final _rng = Random();

  int _rand(int n) => _rng.nextInt(n);

  void _reset() {
    _grid = List.generate(_rows, (_) => List.filled(_cols, -1));
    _score = 0;
    _spawn();
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _tick());
    setState(() {});
  }

  void _spawn() {
    _piece = _rand(7);
    _rot = 0;
    _px = 3;
    _py = 0;
    if (!_valid(_piece, _rot, _px, _py)) {
      // 게임 오버
      _running = false;
      _timer?.cancel();
      widget.onFinish(_score);
    }
  }

  List<List<int>> _cells(int piece, int rot) => _shapes[piece][rot];

  bool _valid(int piece, int rot, int x, int y) {
    for (final c in _cells(piece, rot)) {
      final nx = x + c[0], ny = y + c[1];
      if (nx < 0 || nx >= _cols || ny >= _rows) return false;
      if (ny >= 0 && _grid[ny][nx] != -1) return false;
    }
    return true;
  }

  void _merge() {
    for (final c in _cells(_piece, _rot)) {
      final nx = _px + c[0], ny = _py + c[1];
      if (ny >= 0) _grid[ny][nx] = _piece;
    }
    _clearLines();
    _spawn();
  }

  void _clearLines() {
    var cleared = 0;
    for (var y = _rows - 1; y >= 0; y--) {
      if (_grid[y].every((v) => v != -1)) {
        _grid.removeAt(y);
        _grid.insert(0, List.filled(_cols, -1));
        cleared++;
        y++; // 같은 줄 재검사
      }
    }
    if (cleared > 0) _score += [0, 100, 300, 500, 800][cleared];
  }

  void _tick() {
    if (!_running) return;
    if (_valid(_piece, _rot, _px, _py + 1)) {
      setState(() => _py++);
    } else {
      setState(_merge);
    }
  }

  void _move(int dx) {
    if (_running && _valid(_piece, _rot, _px + dx, _py)) setState(() => _px += dx);
  }

  void _rotate() {
    if (!_running) return;
    final nr = (_rot + 1) % 4;
    if (_valid(_piece, nr, _px, _py)) setState(() => _rot = nr);
  }

  void _drop() {
    if (!_running) return;
    while (_valid(_piece, _rot, _px, _py + 1)) {
      _py++;
    }
    setState(_merge);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('테트리스 🧱   점수 $_score')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _cols / _rows,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  color: Colors.black87,
                  child: _buildGrid(),
                ),
              ),
            ),
          ),
          if (!_running)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  if (_score > 0) Text('게임 오버! 점수: $_score 🎉', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  FilledButton(onPressed: _reset, child: Text(_score > 0 ? '다시 하기' : '시작')),
                ],
              ),
            ),
          if (_running)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ctrl(Icons.arrow_left, () => _move(-1)),
                  _ctrl(Icons.rotate_right, _rotate),
                  _ctrl(Icons.arrow_right, () => _move(1)),
                  _ctrl(Icons.arrow_downward, _drop),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // 현재 조각을 grid 위에 임시로 표시
    final view = List.generate(_rows, (y) => List<int>.from(_grid[y]));
    if (_running) {
      for (final c in _cells(_piece, _rot)) {
        final nx = _px + c[0], ny = _py + c[1];
        if (ny >= 0 && ny < _rows && nx >= 0 && nx < _cols) view[ny][nx] = _piece;
      }
    }
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols),
      itemCount: _rows * _cols,
      itemBuilder: (_, i) {
        final v = view[i ~/ _cols][i % _cols];
        return Container(
          decoration: BoxDecoration(
            color: v == -1 ? const Color(0xFF1A1A1A) : _colors[v],
            border: Border.all(color: const Color(0xFF3A3A3A), width: 0.7), // 격자 실선
          ),
        );
      },
    );
  }

  Widget _ctrl(IconData icon, VoidCallback onTap) => Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(padding: const EdgeInsets.all(14), child: Icon(icon, size: 28)),
        ),
      );
}
