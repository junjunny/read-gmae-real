import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 색깔 맞추기: "글자의 색"과 같은 색 버튼을 빠르게! 30초 동안 많이 맞추기.
class ColorGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const ColorGame({super.key, required this.onFinish});
  @override
  State<ColorGame> createState() => _ColorGameState();
}

const _names = ['빨강', '파랑', '초록', '노랑', '보라'];
const _colors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFDD835), Color(0xFF8E24AA)];

class _ColorGameState extends State<ColorGame> {
  final _rng = Random();
  int _score = 0, _left = 22;
  bool _running = false;
  Timer? _timer;
  int _wordIdx = 0; // 표시되는 글자(텍스트)
  int _colorIdx = 0; // 그 글자의 실제 색 ← 정답
  List<int> _choices = [];

  void _start() {
    _score = 0;
    _left = 22;
    _running = true;
    _newRound();
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

  void _newRound() {
    _wordIdx = _rng.nextInt(_names.length);
    _colorIdx = _rng.nextInt(_colors.length);
    // 선택지 5개 전부(더 헷갈리게)
    _choices = List.generate(_colors.length, (i) => i)..shuffle(_rng);
  }

  void _pick(int c) {
    if (!_running) return;
    setState(() {
      _score += (c == _colorIdx) ? 10 : -5;
      if (_score < 0) _score = 0;
      _newRound();
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
      appBar: AppBar(title: Text('색깔 맞추기 🎨  ⏱️$_left  ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '점수 $_score 🎉' : '글자의 "색깔"과 같은 버튼 누르기!\n(글자 내용 말고 색!)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_names[_wordIdx], style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: _colors[_colorIdx])),
                const SizedBox(height: 8),
                const Text('↑ 이 글자의 색깔은?', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: _choices
                      .map((c) => GestureDetector(
                            onTap: () => _pick(c),
                            child: Container(width: 70, height: 70, decoration: BoxDecoration(color: _colors[c], borderRadius: BorderRadius.circular(14))),
                          ))
                      .toList(),
                ),
              ],
            ),
    );
  }
}
