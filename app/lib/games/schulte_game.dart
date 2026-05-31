import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 1→25를 순서대로 빨리 터치! 빠를수록 고득점.
class SchulteGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const SchulteGame({super.key, required this.onFinish});
  @override
  State<SchulteGame> createState() => _SchulteGameState();
}

class _SchulteGameState extends State<SchulteGame> {
  List<int> _nums = [];
  int _next = 1;
  bool _running = false;
  DateTime? _start;
  Timer? _ticker;
  int _elapsed = 0;

  void _begin() {
    _nums = List.generate(25, (i) => i + 1)..shuffle(Random());
    _next = 1;
    _running = true;
    _start = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _elapsed = DateTime.now().difference(_start!).inMilliseconds);
    });
    setState(() {});
  }

  void _tap(int n) {
    if (!_running) return;
    if (n == _next) {
      _next++;
      if (_next > 25) {
        _running = false;
        _ticker?.cancel();
        final ms = DateTime.now().difference(_start!).inMilliseconds;
        final score = max(0, 60000 - ms) ~/ 100; // 빠를수록 ↑ (최대 600)
        setState(() {});
        widget.onFinish(score);
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('순서 터치 🔢  ${(_elapsed / 1000).toStringAsFixed(1)}s')),
      body: !_running
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_next > 25 ? '완료! ${(_elapsed / 1000).toStringAsFixed(1)}초 🎉' : '1부터 25까지\n순서대로 빨리 터치!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _begin, child: Text(_next > 25 ? '다시' : '시작')),
                ],
              ),
            )
          : Column(
              children: [
                Padding(padding: const EdgeInsets.all(10), child: Text('다음: $_next', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 6, crossAxisSpacing: 6),
                      itemCount: 25,
                      itemBuilder: (_, i) {
                        final n = _nums[i];
                        final done = n < _next;
                        return GestureDetector(
                          onTap: () => _tap(n),
                          child: Container(
                            decoration: BoxDecoration(
                              color: done ? Colors.green.shade200 : Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: Text('$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
