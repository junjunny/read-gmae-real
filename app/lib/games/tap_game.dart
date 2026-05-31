import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 빠른 탭 게임: 15초 동안 나타나는 동그라미를 최대한 많이 탭. score = 탭 횟수.
/// 끝나면 점수를 onFinish로 돌려준다.
class TapGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const TapGame({super.key, required this.onFinish});

  @override
  State<TapGame> createState() => _TapGameState();
}

class _TapGameState extends State<TapGame> {
  static const _duration = 15;
  int _score = 0;
  int _left = _duration;
  bool _running = false;
  Timer? _timer;
  Alignment _target = Alignment.center;
  final _rng = Random();

  double _rand() => _rng.nextDouble();

  void _move() {
    _target = Alignment(_rand() * 1.6 - 0.8, _rand() * 1.6 - 0.8);
  }

  void _start() {
    setState(() {
      _score = 0;
      _left = _duration;
      _running = true;
      _move();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _running = false);
        widget.onFinish(_score);
      }
    });
  }

  void _hit() {
    if (!_running) return;
    setState(() {
      _score++;
      _move();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('빠른 탭 ⚡')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('⏱️ $_left초', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('🎯 $_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              child: _running
                  ? Align(
                      alignment: _target,
                      child: GestureDetector(
                        onTap: _hit,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.touch_app, color: Colors.white),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '점수: $_score 🎉' : '15초 동안 최대한 많이 탭!', style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시 하기' : '시작')),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
