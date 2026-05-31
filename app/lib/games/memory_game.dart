import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 카드 짝맞추기: 8쌍(16장)을 뒤집어 짝 맞추기. 빠를수록 + 적게 틀릴수록 고득점.
class MemoryGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const MemoryGame({super.key, required this.onFinish});
  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

const _emojis = ['🍎', '🐶', '⭐', '🌸', '🍕', '🎈', '🐱', '🚀'];

class _MemoryGameState extends State<MemoryGame> {
  List<String> _cards = [];
  final Set<int> _matched = {};
  final List<int> _flipped = [];
  int _tries = 0;
  bool _busy = false;
  bool _started = false;
  DateTime? _start;
  Timer? _ticker;
  int _elapsed = 0;

  void _begin() {
    _cards = [..._emojis, ..._emojis]..shuffle(Random());
    _matched.clear();
    _flipped.clear();
    _tries = 0;
    _started = true;
    _start = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() => _elapsed = DateTime.now().difference(_start!).inSeconds));
    setState(() {});
  }

  Future<void> _tap(int i) async {
    if (_busy || _flipped.contains(i) || _matched.contains(i)) return;
    setState(() => _flipped.add(i));
    if (_flipped.length == 2) {
      _tries++;
      _busy = true;
      final a = _flipped[0], b = _flipped[1];
      if (_cards[a] == _cards[b]) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _matched.addAll([a, b]);
          _flipped.clear();
          _busy = false;
        });
        if (_matched.length == _cards.length) _finish();
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() {
          _flipped.clear();
          _busy = false;
        });
      }
    }
  }

  void _finish() {
    _ticker?.cancel();
    final sec = DateTime.now().difference(_start!).inSeconds;
    // 빠르고 적게 틀릴수록 ↑ (최대 1000)
    final score = max(0, 1000 - sec * 8 - (_tries - 8) * 15);
    _started = false;
    setState(() {});
    widget.onFinish(score);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('카드 짝맞추기 🃏  ⏱️${_elapsed}s  시도 $_tries')),
      body: !_started
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('같은 카드 8쌍을 빨리 맞춰요!\n빠르고 적게 틀릴수록 고득점', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _begin, child: const Text('시작')),
              ]),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: _cards.length,
                itemBuilder: (_, i) {
                  final show = _flipped.contains(i) || _matched.contains(i);
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _matched.contains(i) ? Colors.green.shade100 : (show ? Colors.white : Theme.of(context).colorScheme.primary),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(child: Text(show ? _cards[i] : '?', style: TextStyle(fontSize: 30, color: show ? null : Colors.white))),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
