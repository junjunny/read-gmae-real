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
  int _hold = -1; // 홀드 중인 조각(-1=없음)
  bool _holdUsed = false; // 조각당 1회만 홀드 가능
  int _score = 0;
  bool _running = false;
  Timer? _timer;
  final _rng = Random();

  int _rand(int n) => _rng.nextInt(n);

  void _reset() {
    _grid = List.generate(_rows, (_) => List.filled(_cols, -1));
    _score = 0;
    _hold = -1;
    _spawn();
    _running = true;
    _restartTimer();
    setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    final ms = max(140, 430 - (_score ~/ 200) * 25); // 시작 빠르게 + 점수 오를수록 가속
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  void _spawn() {
    _piece = _rand(7);
    _rot = 0;
    _px = 3;
    _py = 0;
    _holdUsed = false; // 새 조각마다 홀드 재사용 가능
    if (!_valid(_piece, _rot, _px, _py)) {
      // 게임 오버
      _running = false;
      _timer?.cancel();
      widget.onFinish(_score);
    }
  }

  void _holdPiece() {
    if (!_running || _holdUsed) return;
    setState(() {
      if (_hold == -1) {
        _hold = _piece;
        _spawn();
      } else {
        final t = _hold;
        _hold = _piece;
        _piece = t;
        _rot = 0;
        _px = 3;
        _py = 0;
        if (!_valid(_piece, _rot, _px, _py)) {
          _running = false;
          _timer?.cancel();
          widget.onFinish(_score);
          return;
        }
      }
      _holdUsed = true;
    });
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
    if (cleared > 0) {
      _score += [0, 100, 300, 500, 800][cleared];
      _restartTimer(); // 점수 오르면 더 빠르게
    }
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
          if (_running)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Text('홀드 ', style: TextStyle(fontWeight: FontWeight.bold)),
                  _holdPreview(),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _holdUsed ? null : _holdPiece,
                    icon: const Icon(Icons.swap_vert, size: 18),
                    label: const Text('홀드'),
                  ),
                ],
              ),
            ),
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

  Widget _holdPreview() {
    if (_hold == -1) {
      return Container(
        width: 56,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4)),
        child: const Text('—', style: TextStyle(color: Colors.white54)),
      );
    }
    final cells = _shapes[_hold][0];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4)),
      child: SizedBox(
        width: 56,
        height: 28,
        child: Stack(
          children: [
            for (final c in cells)
              Positioned(
                left: c[0] * 13.0,
                top: c[1] * 13.0,
                width: 12,
                height: 12,
                child: Container(color: _colors[_hold]),
              ),
          ],
        ),
      ),
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
