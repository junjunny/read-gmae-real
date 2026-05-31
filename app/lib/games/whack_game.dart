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
  // 동시에 여러 칸 등장 가능: 칸별 상태(0=없음,1=두더지,2=폭탄)
  List<int> _holes = List.filled(9, 0);

  void _start() {
    _score = 0;
    _left = 20;
    _holes = List.filled(9, 0);
    _running = true;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    _pop();
    setState(() {});
  }

  // 진행할수록 빨라지고 노출시간 짧아짐
  int get _gap {
    final elapsed = 20 - _left;
    return max(280, 620 - elapsed * 18); // 점점 촘촘
  }

  int get _showMs {
    final elapsed = 20 - _left;
    return max(450, 900 - elapsed * 25); // 노출시간 점점 짧게(놓치면 사라짐)
  }

  void _pop() {
    if (!_running) return;
    // 한 번에 1~2칸 등장
    final count = _rng.nextInt(2) + 1;
    for (var n = 0; n < count; n++) {
      final empty = [for (var i = 0; i < 9; i++) if (_holes[i] == 0) i];
      if (empty.isEmpty) break;
      final idx = empty[_rng.nextInt(empty.length)];
      final isBomb = _rng.nextInt(3) == 0; // 33% 폭탄
      _holes[idx] = isBomb ? 2 : 1;
      // 일정 시간 뒤 자동으로 사라짐(놓침)
      Timer(Duration(milliseconds: _showMs), () {
        if (mounted && _holes[idx] != 0) setState(() => _holes[idx] = 0);
      });
    }
    setState(() {});
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _gap), _pop);
  }

  void _tap(int i) {
    if (!_running || _holes[i] == 0) return;
    setState(() {
      if (_holes[i] == 2) {
        _score = max(0, _score - 20); // 폭탄 패널티 ↑
      } else {
        _score += 10;
      }
      _holes[i] = 0;
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
                  final state = _holes[i];
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.brown.shade200, borderRadius: BorderRadius.circular(60), border: Border.all(color: Colors.brown.shade400, width: 3)),
                      child: Center(child: Text(state == 2 ? '💣' : (state == 1 ? '🐹' : ''), style: const TextStyle(fontSize: 44))),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
