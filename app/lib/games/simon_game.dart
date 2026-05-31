import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 기억력 순서: 불이 켜지는 순서를 기억해 똑같이 누르기. 라운드가 곧 점수.
class SimonGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const SimonGame({super.key, required this.onFinish});
  @override
  State<SimonGame> createState() => _SimonGameState();
}

const _btnColors = [Color(0xFF43A047), Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFDD835)];

class _SimonGameState extends State<SimonGame> {
  final _rng = Random();
  final List<int> _seq = [];
  int _inputIdx = 0;
  int _flash = -1;
  bool _showing = false;
  bool _running = false;

  void _start() {
    _seq.clear();
    _running = true;
    _nextRound();
  }

  void _nextRound() {
    _seq.add(_rng.nextInt(4));
    _inputIdx = 0;
    _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() => _showing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    for (final c in _seq) {
      setState(() => _flash = c);
      await Future.delayed(const Duration(milliseconds: 450));
      setState(() => _flash = -1);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    setState(() => _showing = false);
  }

  Future<void> _tap(int c) async {
    if (!_running || _showing) return;
    setState(() => _flash = c);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _flash = -1);
    if (c == _seq[_inputIdx]) {
      _inputIdx++;
      if (_inputIdx == _seq.length) {
        await Future.delayed(const Duration(milliseconds: 300));
        _nextRound();
      }
    } else {
      // 틀림 → 종료. 점수 = 맞춘 라운드 수 * 50
      _running = false;
      final score = (_seq.length - 1) * 50;
      setState(() {});
      widget.onFinish(score);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('기억력 순서 🧠  Lv.${_seq.isEmpty ? 0 : _seq.length}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              !_running
                  ? (_seq.isNotEmpty ? '게임 오버! Lv.${_seq.length} 도달 🎉' : '불이 켜진 순서를 기억해\n똑같이 누르세요!')
                  : (_showing ? '잘 보세요... 👀' : '따라 누르세요! (${_inputIdx + 1}/${_seq.length})'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: List.generate(4, (i) {
                  final on = _flash == i;
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: AnimatedOpacity(
                      opacity: on ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 80),
                      child: Container(decoration: BoxDecoration(color: _btnColors[i], borderRadius: BorderRadius.circular(16))),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (!_running)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(onPressed: _start, child: Text(_seq.isNotEmpty ? '다시' : '시작')),
            ),
        ],
      ),
    );
  }
}
