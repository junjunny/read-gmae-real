import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 빠른 계산: 30초 동안 사칙연산 많이 맞히기. 정답 +10, 오답 -5.
class MathGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const MathGame({super.key, required this.onFinish});
  @override
  State<MathGame> createState() => _MathGameState();
}

class _MathGameState extends State<MathGame> {
  final _rng = Random();
  int _score = 0, _left = 30;
  bool _running = false;
  Timer? _timer;
  late int _a, _b, _ans;
  late String _op;
  List<int> _choices = [];

  void _start() {
    _score = 0;
    _left = 30;
    _running = true;
    _newQ();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) {
        _timer?.cancel();
        setState(() => _running = false);
        widget.onFinish(_score);
      }
    });
    setState(() {});
  }

  void _newQ() {
    final ops = ['+', '-', '×'];
    _op = ops[_rng.nextInt(3)];
    if (_op == '×') {
      _a = _rng.nextInt(9) + 1;
      _b = _rng.nextInt(9) + 1;
      _ans = _a * _b;
    } else if (_op == '+') {
      _a = _rng.nextInt(50) + 1;
      _b = _rng.nextInt(50) + 1;
      _ans = _a + _b;
    } else {
      _a = _rng.nextInt(50) + 10;
      _b = _rng.nextInt(_a);
      _ans = _a - _b;
    }
    final set = <int>{_ans};
    while (set.length < 4) {
      set.add(_ans + _rng.nextInt(11) - 5);
    }
    _choices = set.toList()..shuffle(_rng);
  }

  void _pick(int v) {
    if (!_running) return;
    setState(() {
      _score += (v == _ans) ? 10 : -5;
      if (_score < 0) _score = 0;
      _newQ();
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
      appBar: AppBar(title: Text('빠른 계산 🧮  ⏱️$_left  ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '점수 $_score 🎉' : '30초 동안 최대한 많이 맞히기!', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_a $_op $_b = ?', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: _choices
                      .map((v) => SizedBox(
                            width: 120,
                            height: 60,
                            child: FilledButton(onPressed: () => _pick(v), child: Text('$v', style: const TextStyle(fontSize: 22))),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
