import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 사과게임 🍎: 2분 동안 드래그로 사각형을 그려 그 안의 사과 숫자 합이 "딱 10"이면 제거! 제거한 사과 수만큼 점수.
/// 👑 황금 사과가 포함되면 주변 사과까지 자동 제거 / ⏰ 시간 사과를 없애면 +10초.
class AppleGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const AppleGame({super.key, required this.onFinish});
  @override
  State<AppleGame> createState() => _AppleGameState();
}

const int _cols = 9;
const int _rows = 11;

class _AppleGameState extends State<AppleGame> {
  final _rng = Random();
  late List<List<int>> _v; // 1~9, 0=빈칸
  final Set<int> _golden = {}; // r*_cols+c
  final Set<int> _timeApple = {};
  int _score = 0;
  int _left = 120;
  bool _running = false;
  Timer? _clock;

  // 드래그 선택 영역(행/열 인덱스)
  int? _r1, _c1, _r2, _c2;

  void _start() {
    _v = List.generate(_rows, (_) => List.generate(_cols, (_) => _rng.nextInt(9) + 1));
    _golden.clear();
    _timeApple.clear();
    for (var i = 0; i < _rows * _cols; i++) {
      final roll = _rng.nextInt(100);
      if (roll < 5) {
        _golden.add(i);
      } else if (roll < 10) {
        _timeApple.add(i);
      }
    }
    _score = 0;
    _left = 120;
    _running = true;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    setState(() {});
  }

  void _onPanStart(int r, int c) {
    _r1 = _r2 = r;
    _c1 = _c2 = c;
    setState(() {});
  }

  void _onPanTo(int r, int c) {
    _r2 = r;
    _c2 = c;
    setState(() {});
  }

  void _onPanEnd() {
    if (_r1 == null) return;
    final r0 = min(_r1!, _r2!), r1 = max(_r1!, _r2!);
    final c0 = min(_c1!, _c2!), c1 = max(_c1!, _c2!);
    final selected = <int>[];
    var sum = 0;
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (_v[r][c] > 0) {
          selected.add(r * _cols + c);
          sum += _v[r][c];
        }
      }
    }
    if (sum == 10 && selected.isNotEmpty) {
      _clearCells(selected);
    }
    _r1 = _c1 = _r2 = _c2 = null;
    setState(() {});
  }

  void _clearCells(List<int> cells) {
    var addTime = 0;
    final toClear = <int>{...cells};
    // 황금 사과 포함 시 주변 8칸 자동 제거
    for (final idx in cells) {
      if (_golden.contains(idx)) {
        final r = idx ~/ _cols, c = idx % _cols;
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < _rows && nc >= 0 && nc < _cols && _v[nr][nc] > 0) {
              toClear.add(nr * _cols + nc);
            }
          }
        }
      }
    }
    for (final idx in toClear) {
      if (_timeApple.contains(idx)) addTime += 10;
      _v[idx ~/ _cols][idx % _cols] = 0;
      _golden.remove(idx);
      _timeApple.remove(idx);
    }
    _score += toClear.length;
    if (addTime > 0) _left += addTime;
  }

  bool _inSel(int r, int c) {
    if (_r1 == null) return false;
    final r0 = min(_r1!, _r2!), r1 = max(_r1!, _r2!);
    final c0 = min(_c1!, _c2!), c1 = max(_c1!, _c2!);
    return r >= r0 && r <= r1 && c >= c0 && c <= c1;
  }

  void _end() {
    _running = false;
    _clock?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('사과게임 🍎   ⏱️$_left초   ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '끝! $_score개 제거 🍎' : '드래그로 사각형을 그려\n합이 "딱 10"이 되는 사과를 없애요! (2분)\n👑황금=주변까지 · ⏰=시간+10초', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                final cw = w / _cols, ch = h / _rows;
                void handle(Offset local, bool start) {
                  final c = (local.dx / cw).floor().clamp(0, _cols - 1);
                  final r = (local.dy / ch).floor().clamp(0, _rows - 1);
                  if (start) {
                    _onPanStart(r, c);
                  } else {
                    _onPanTo(r, c);
                  }
                }

                return GestureDetector(
                  onPanStart: (d) => handle(d.localPosition, true),
                  onPanUpdate: (d) => handle(d.localPosition, false),
                  onPanEnd: (_) => _onPanEnd(),
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFFFFFDE7)),
                      for (var r = 0; r < _rows; r++)
                        for (var c = 0; c < _cols; c++)
                          if (_v[r][c] > 0)
                            Positioned(
                              left: c * cw + 2,
                              top: r * ch + 2,
                              width: cw - 4,
                              height: ch - 4,
                              child: _apple(r * _cols + c, _v[r][c]),
                            ),
                      // 선택 영역 표시
                      if (_r1 != null)
                        Positioned(
                          left: min(_c1!, _c2!) * cw,
                          top: min(_r1!, _r2!) * ch,
                          width: (max(_c1!, _c2!) - min(_c1!, _c2!) + 1) * cw,
                          height: (max(_r1!, _r2!) - min(_r1!, _r2!) + 1) * ch,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(4),
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

  Widget _apple(int idx, int val) {
    final golden = _golden.contains(idx);
    final timeA = _timeApple.contains(idx);
    final sel = _inSel(idx ~/ _cols, idx % _cols);
    Color bg = const Color(0xFFE53935);
    if (golden) bg = const Color(0xFFFFB300);
    if (timeA) bg = const Color(0xFF26A69A);
    return Container(
      decoration: BoxDecoration(
        color: sel ? Color.lerp(bg, Colors.white, 0.35) : bg,
        shape: BoxShape.circle,
        border: golden ? Border.all(color: Colors.orange.shade900, width: 2) : null,
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              timeA ? '⏰$val' : (golden ? '👑$val' : '$val'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
