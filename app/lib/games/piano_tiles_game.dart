import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 피아노 타일: 내려오는 검은 타일을 놓치지 말고 탭! 점점 빨라짐. 하나라도 놓치면 끝.
class PianoTilesGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const PianoTilesGame({super.key, required this.onFinish});
  @override
  State<PianoTilesGame> createState() => _PianoTilesGameState();
}

class _Tile {
  int lane;
  double y; // 0(위)~1(아래)
  bool hit = false;
  _Tile(this.lane, this.y);
}

class _PianoTilesGameState extends State<PianoTilesGame> {
  static const lanes = 4;
  final _rng = Random();
  final List<_Tile> _tiles = [];
  int _score = 0;
  bool _running = false;
  Timer? _loop;
  double _spawnAcc = 0;

  double get _speed => 0.013 + _score * 0.0006; // 점점 빨라짐
  double get _spawnGap => max(0.28, 0.62 - _score * 0.012); // 점점 촘촘

  void _start() {
    _tiles.clear();
    _score = 0;
    _spawnAcc = 1;
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    setState(() {});
  }

  void _tick() {
    if (!_running) return;
    for (final t in _tiles) {
      t.y += _speed;
    }
    // 놓친 타일(바닥 통과, 안 친 것) → 게임오버
    for (final t in _tiles) {
      if (!t.hit && t.y > 1.02) {
        _end();
        return;
      }
    }
    _tiles.removeWhere((t) => t.y > 1.15);
    // 스폰
    _spawnAcc += _speed;
    if (_spawnAcc >= _spawnGap) {
      _spawnAcc = 0;
      _tiles.add(_Tile(_rng.nextInt(lanes), -0.25));
    }
    setState(() {});
  }

  void _tapLane(int lane) {
    if (!_running) return;
    // 그 레인에서 가장 아래쪽의 안 친 타일을 친다
    _Tile? target;
    for (final t in _tiles) {
      if (t.lane == lane && !t.hit) {
        if (target == null || t.y > target.y) target = t;
      }
    }
    if (target == null) {
      _end(); // 빈 곳 탭 = 실패
      return;
    }
    setState(() {
      target!.hit = true;
      _score++;
    });
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
      appBar: AppBar(title: Text('피아노 타일 🎹   $_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '놓쳤다! 점수 $_score 🎹' : '내려오는 검은 타일을 놓치지 말고\n탭! 점점 빨라져요.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final laneW = w / lanes;
              return Stack(
                children: [
                  // 레인 구분선
                  for (var i = 1; i < lanes; i++)
                    Positioned(left: laneW * i, top: 0, bottom: 0, child: Container(width: 1, color: Colors.grey.shade300)),
                  // 타일
                  for (final t in _tiles)
                    Positioned(
                      left: t.lane * laneW + 3,
                      top: t.y * h,
                      width: laneW - 6,
                      height: h * 0.22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.hit ? Colors.grey.shade300 : const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // 탭 영역(레인별)
                  Row(
                    children: [
                      for (var i = 0; i < lanes; i++)
                        Expanded(child: GestureDetector(onTapDown: (_) => _tapLane(i), child: Container(color: Colors.transparent))),
                    ],
                  ),
                ],
              );
            }),
    );
  }
}
