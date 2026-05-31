import 'dart:async';

import 'package:flutter/material.dart';

/// 틀린 그림 찾기: 위/아래 두 이모지 그리드가 거의 같지만 N칸이 다름.
/// 아래 그리드에서 다른 칸을 모두 탭하면 끝. 점수 = 찾은 수*100 - 오답*30 (+ 시간보너스).
class SpotDifferenceGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const SpotDifferenceGame({super.key, required this.onFinish});

  @override
  State<SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

const int _cols = 5;
const int _rows = 5;
const int _diffCount = 5;
const int _timeLimit = 60;

const List<String> _emojis = ['🍎', '🍊', '🍋', '🍉', '🍇', '🍓', '🐶', '🐱', '🐰', '🐻', '⭐', '❤️', '🌸', '🍀'];

class _SpotDifferenceGameState extends State<SpotDifferenceGame> {
  late List<String> _top;
  late List<String> _bottom;
  late Set<int> _diffs; // 다른 칸 인덱스
  final Set<int> _found = {};
  int _wrong = 0;
  int _left = _timeLimit;
  bool _running = false;
  Timer? _timer;
  int _seed = 24680;

  int _rand(int n) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % n;
  }

  void _start() {
    const n = _cols * _rows;
    _top = List.generate(n, (_) => _emojis[_rand(_emojis.length)]);
    _bottom = List.from(_top);
    _diffs = {};
    while (_diffs.length < _diffCount) {
      _diffs.add(_rand(n));
    }
    for (final i in _diffs) {
      // 다른 이모지로 교체
      var e = _emojis[_rand(_emojis.length)];
      while (e == _top[i]) {
        e = _emojis[_rand(_emojis.length)];
      }
      _bottom[i] = e;
    }
    _found.clear();
    _wrong = 0;
    _left = _timeLimit;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    setState(() {});
  }

  void _tap(int i) {
    if (!_running || _found.contains(i)) return;
    setState(() {
      if (_diffs.contains(i)) {
        _found.add(i);
        if (_found.length == _diffCount) _end();
      } else {
        _wrong++;
      }
    });
  }

  void _end() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    final score = (_found.length * 100 - _wrong * 30 + _left * 5).clamp(0, 999);
    setState(() {});
    widget.onFinish(score);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('틀린 그림 찾기 🔍')),
      body: _running
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('⏱️ $_left', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('찾음 ${_found.length}/$_diffCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('오답 $_wrong', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                Expanded(child: _grid(_top, tappable: false)),
                const Divider(height: 1),
                const Padding(padding: EdgeInsets.all(4), child: Text('↓ 아래에서 다른 곳을 찾아 탭!', style: TextStyle(fontSize: 12, color: Colors.grey))),
                Expanded(child: _grid(_bottom, tappable: true)),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_found.isEmpty && _wrong == 0 ? '두 그림에서 다른 곳 $_diffCount개를 찾아라!' : '끝! 찾음 ${_found.length}/$_diffCount, 오답 $_wrong',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _start, child: const Text('시작')),
                ],
              ),
            ),
    );
  }

  Widget _grid(List<String> data, {required bool tappable}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final isFound = tappable && _found.contains(i);
        return GestureDetector(
          onTap: tappable ? () => _tap(i) : null,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isFound ? Colors.green.shade200 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: isFound ? Border.all(color: Colors.green, width: 2) : null,
            ),
            child: Center(child: Text(data[i], style: const TextStyle(fontSize: 22))),
          ),
        );
      },
    );
  }
}
