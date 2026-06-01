import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 빠른 탭 게임: 15초 동안 나타나는 동그라미를 최대한 많이 탭.
/// ⭐ 황금 탭(랜덤): x2점 / 🔥 콤보 10개마다 보너스(+5).
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
  int _combo = 0;
  bool _running = false;
  bool _golden = false;
  String? _fx; // 떠오르는 점수 피드백
  Timer? _timer;
  Alignment _target = Alignment.center;
  final _rng = Random();

  double _rand() => _rng.nextDouble();

  void _move() {
    _target = Alignment(_rand() * 1.6 - 0.8, _rand() * 1.6 - 0.8);
    _golden = _rng.nextInt(5) == 0; // 20% 확률 황금 탭
  }

  void _start() {
    setState(() {
      _score = 0;
      _left = _duration;
      _combo = 0;
      _fx = null;
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
      final gain = _golden ? 2 : 1;
      _score += gain;
      _combo++;
      _fx = _golden ? '⭐ +2' : '+1';
      if (_combo % 10 == 0) {
        _score += 5;
        _fx = '🔥 콤보 $_combo! +5';
      }
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
                Text('🔥 콤보 $_combo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _combo > 0 ? Colors.deepOrange : Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              child: _running
                  ? Stack(
                      children: [
                        Align(
                          alignment: _target,
                          child: GestureDetector(
                            onTap: _hit,
                            child: Container(
                              width: _golden ? 48 : 42,
                              height: _golden ? 48 : 42,
                              decoration: BoxDecoration(
                                color: _golden ? const Color(0xFFFFC107) : Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: _golden ? [const BoxShadow(color: Color(0xAAFFC107), blurRadius: 16, spreadRadius: 2)] : null,
                              ),
                              child: Icon(_golden ? Icons.star : Icons.touch_app, color: Colors.white, size: _golden ? 26 : 20),
                            ),
                          ),
                        ),
                        if (_fx != null)
                          Align(
                            alignment: Alignment(_target.x, _target.y - 0.25),
                            child: Text(_fx!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_score > 0 ? '점수: $_score 🎉' : '15초 동안 점을 최대한 많이 탭!\n⭐황금 탭은 x2점 · 🔥콤보 10마다 보너스', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
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
