import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 하트 받기: 바구니를 좌우로 움직여 떨어지는 💝 받기! 💣 폭탄은 피하기. 30초.
class CatchGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const CatchGame({super.key, required this.onFinish});
  @override
  State<CatchGame> createState() => _CatchGameState();
}

class _Item {
  double x; // 0~1
  double y; // 0(위)~1(아래)
  final bool bomb;
  _Item(this.x, this.y, this.bomb);
}

class _CatchGameState extends State<CatchGame> {
  final _rng = Random();
  final List<_Item> _items = [];
  double _basket = 0.5;
  int _score = 0, _left = 30;
  bool _running = false;
  Timer? _loop, _clock, _spawn;

  void _start() {
    _items.clear();
    _basket = 0.5;
    _score = 0;
    _left = 30;
    _running = true;
    _loop?.cancel();
    _clock?.cancel();
    _spawn?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    _spawn = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _items.add(_Item(_rng.nextDouble(), 0, _rng.nextInt(4) == 0));
    });
    setState(() {});
  }

  void _tick() {
    if (!_running) return;
    for (final it in _items) {
      it.y += 0.02;
    }
    _items.removeWhere((it) {
      if (it.y >= 0.9 && (it.x - _basket).abs() < 0.12) {
        // 받음
        _score += it.bomb ? -15 : 10;
        if (_score < 0) _score = 0;
        return true;
      }
      return it.y > 1.05;
    });
    setState(() {});
  }

  void _end() {
    _running = false;
    _loop?.cancel();
    _clock?.cancel();
    _spawn?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _clock?.cancel();
    _spawn?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('하트 받기 💝  ⏱️$_left  ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '점수 $_score 🎉' : '바구니를 움직여 💝를 받고\n💣은 피하세요! (드래그)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : LayoutBuilder(builder: (context, box) {
              return GestureDetector(
                onPanUpdate: (d) => setState(() => _basket = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
                onTapDown: (d) => setState(() => _basket = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
                child: Container(
                  color: const Color(0xFFEAF6FF),
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      for (final it in _items)
                        Align(
                          alignment: Alignment(it.x * 2 - 1, it.y * 2 - 1),
                          child: Text(it.bomb ? '💣' : '💝', style: const TextStyle(fontSize: 30)),
                        ),
                      Align(
                        alignment: Alignment(_basket * 2 - 1, 0.95),
                        child: const Text('🧺', style: TextStyle(fontSize: 44)),
                      ),
                    ],
                  ),
                ),
              );
            }),
    );
  }
}
