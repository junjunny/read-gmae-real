import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 두더지 잡기: 9칸 중 튀어나오는 두더지(🐹)를 탭! 폭탄(💣)은 누르면 감점. 20초.
class WhackGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const WhackGame({super.key, required this.onFinish});
  @override
  State<WhackGame> createState() => _WhackGameState();
}

class _WhackGameState extends State<WhackGame> {
  final _rng = Random();
  int _score = 0, _left = 20;
  bool _running = false;
  Timer? _spawnTimer, _clock;
  int _active = -1; // 현재 튀어나온 칸
  bool _isBomb = false;

  void _start() {
    _score = 0;
    _left = 20;
    _running = true;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    _pop();
    setState(() {});
  }

  void _pop() {
    if (!_running) return;
    setState(() {
      _active = _rng.nextInt(9);
      _isBomb = _rng.nextInt(5) == 0; // 20% 폭탄
    });
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: 650 + _rng.nextInt(500)), _pop);
  }

  void _tap(int i) {
    if (!_running || i != _active) return;
    setState(() {
      if (_isBomb) {
        _score = max(0, _score - 15);
      } else {
        _score += 10;
      }
      _active = -1;
    });
  }

  void _end() {
    _running = false;
    _spawnTimer?.cancel();
    _clock?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('두더지 잡기 🔨  ⏱️$_left  ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '점수 $_score 🎉' : '🐹 두더지는 탭! 💣 폭탄은 피하기!\n20초 동안 최대한 많이!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
                itemCount: 9,
                itemBuilder: (_, i) {
                  final active = i == _active;
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.brown.shade200, borderRadius: BorderRadius.circular(60), border: Border.all(color: Colors.brown.shade400, width: 3)),
                      child: Center(child: Text(active ? (_isBomb ? '💣' : '🐹') : '', style: const TextStyle(fontSize: 44))),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
