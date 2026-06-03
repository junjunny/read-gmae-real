import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

/// 스네이크 🐍: 먹이를 먹으면 길어지고 점점 빨라짐. 벽이나 몸통에 부딪히면 끝.
/// 점수 = 먹은 먹이 수. 스와이프(또는 방향 버튼)로 조작.
/// 🐢 스페셜 먹이를 먹으면 잠시 속도가 느려진다(+2점).
class SnakeGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const SnakeGame({super.key, required this.onFinish});
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const int cols = 17;
  static const int rows = 24;
  final _rng = Random();

  List<Point<int>> _snake = [];
  Point<int> _dir = const Point(0, -1); // 시작: 위로
  Point<int> _pendingDir = const Point(0, -1);
  Point<int> _food = const Point(0, 0);
  Point<int>? _special; // 스페셜 먹이(있을 때만)
  int _specialTtl = 0; // 스페셜 먹이 잔여 틱(0이면 사라짐)
  int _slowTicks = 0; // 감속 효과 잔여 틱
  int _score = 0;
  bool _running = false;
  Timer? _loop;

  // 점점 빨라짐: 시작 220ms → 최소 80ms. 감속 효과 중엔 +130ms.
  int get _tickMs {
    final base = max(80, 220 - _score * 7);
    return _slowTicks > 0 ? base + 130 : base;
  }

  void _start() {
    _snake = [const Point(cols ~/ 2, rows ~/ 2), const Point(cols ~/ 2, rows ~/ 2 + 1)];
    _dir = const Point(0, -1);
    _pendingDir = const Point(0, -1);
    _score = 0;
    _special = null;
    _specialTtl = 0;
    _slowTicks = 0;
    _spawnFood();
    _running = true;
    _schedule();
    setState(() {});
  }

  void _schedule() {
    _loop?.cancel();
    _loop = Timer(Duration(milliseconds: _tickMs), _tick);
  }

  void _spawnFood() {
    while (true) {
      final p = Point(_rng.nextInt(cols), _rng.nextInt(rows));
      if (!_snake.contains(p) && p != _special) {
        _food = p;
        return;
      }
    }
  }

  void _maybeSpawnSpecial() {
    if (_special != null) return;
    if (_rng.nextInt(100) >= 18) return; // 18% 확률로 등장
    for (var i = 0; i < 30; i++) {
      final p = Point(_rng.nextInt(cols), _rng.nextInt(rows));
      if (!_snake.contains(p) && p != _food) {
        _special = p;
        _specialTtl = 45; // 약 45틱 후 사라짐
        return;
      }
    }
  }

  void _tick() {
    if (!_running) return;
    if (_slowTicks > 0) _slowTicks--;
    if (_special != null && --_specialTtl <= 0) _special = null;

    _dir = _pendingDir;
    final head = _snake.first;
    final next = Point(head.x + _dir.x, head.y + _dir.y);

    // 벽 충돌
    if (next.x < 0 || next.x >= cols || next.y < 0 || next.y >= rows) {
      _end();
      return;
    }
    final ateFood = next == _food;
    final ateSpecial = _special != null && next == _special;
    // 몸통 충돌 (먹이 먹어 길어질 때 외엔 꼬리는 곧 비므로 제외)
    final body = ateFood ? _snake : _snake.sublist(0, _snake.length - 1);
    if (body.contains(next)) {
      _end();
      return;
    }

    _snake.insert(0, next);
    if (ateFood) {
      _score++;
      _spawnFood();
      _maybeSpawnSpecial();
    } else {
      _snake.removeLast();
    }
    if (ateSpecial) {
      _score += 2;
      _slowTicks = 40; // 잠깐 느려짐
      _special = null;
    }
    setState(() {});
    _schedule();
  }

  void _turn(Point<int> d) {
    // 반대 방향으로는 못 꺾음
    if (d.x == -_dir.x && d.y == -_dir.y) return;
    if (d.x == _dir.x && d.y == _dir.y) return;
    _pendingDir = d;
  }

  void _onPan(DragUpdateDetails d) {
    final dx = d.delta.dx, dy = d.delta.dy;
    if (dx.abs() < 1.5 && dy.abs() < 1.5) return;
    if (dx.abs() > dy.abs()) {
      _turn(Point(dx > 0 ? 1 : -1, 0));
    } else {
      _turn(Point(0, dy > 0 ? 1 : -1));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: GameTitle('🐍  $_score${_slowTicks > 0 ? '  🐢 감속!' : ''}')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '부딪혔다! 점수 $_score 🐍' : '스와이프로 방향을 바꿔\n먹이(🍎)를 먹어요. 점점 빨라져요!',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onPanUpdate: _onPan,
                      child: AspectRatio(
                        aspectRatio: cols / rows,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
                            ),
                            border: Border.all(color: Colors.green.shade300, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomPaint(painter: _SnakePainter(_snake, _food, _special)),
                        ),
                      ),
                    ),
                  ),
                ),
                _dpad(),
                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Widget _dpad() {
    Widget btn(IconData ic, Point<int> d) => InkWell(
          onTap: () => _turn(d),
          child: Container(
            margin: const EdgeInsets.all(4),
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(ic, size: 30, color: Colors.green.shade800),
          ),
        );
    return Column(
      children: [
        btn(Icons.keyboard_arrow_up, const Point(0, -1)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_left, const Point(-1, 0)),
            const SizedBox(width: 56),
            btn(Icons.keyboard_arrow_right, const Point(1, 0)),
          ],
        ),
        btn(Icons.keyboard_arrow_down, const Point(0, 1)),
      ],
    );
  }
}

class _SnakePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int> food;
  final Point<int>? special;
  _SnakePainter(this.snake, this.food, this.special);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / _SnakeGameState.cols;
    final ch = size.height / _SnakeGameState.rows;

    // 먹이
    final fp = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(Offset((food.x + 0.5) * cw, (food.y + 0.5) * ch), min(cw, ch) * 0.4, fp);

    // 스페셜 먹이(파란 별 모양 대용: 파란 원 + 흰 테두리)
    final sp = special;
    if (sp != null) {
      final c = Offset((sp.x + 0.5) * cw, (sp.y + 0.5) * ch);
      canvas.drawCircle(c, min(cw, ch) * 0.46, Paint()..color = const Color(0xFF1E88E5));
      canvas.drawCircle(c, min(cw, ch) * 0.46, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(c, min(cw, ch) * 0.18, Paint()..color = Colors.white);
    }

    // 뱀
    for (var i = 0; i < snake.length; i++) {
      final s = snake[i];
      final paint = Paint()..color = i == 0 ? const Color(0xFF2E7D32) : const Color(0xFF66BB6A);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s.x * cw + 1, s.y * ch + 1, cw - 2, ch - 2),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
