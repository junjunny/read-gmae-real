import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 색깔 맞추기: 22초 동안 빠르게! 초반 3색 → 후반 7색으로 점점 어려워짐.
/// 📢 페이크 문제(글자 '뜻'의 색을 고르기) / 🔥 5콤보 x2점 / ✨ 10콤보 반짝+보너스(+50).
class ColorGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const ColorGame({super.key, required this.onFinish});
  @override
  State<ColorGame> createState() => _ColorGameState();
}

const _names = ['빨강', '파랑', '초록', '노랑', '보라', '주황', '분홍'];
const _colors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFDD835),
  Color(0xFF8E24AA), Color(0xFFFB8C00), Color(0xFFEC407A),
];

class _ColorGameState extends State<ColorGame> {
  final _rng = Random();
  static const _dur = 22;
  int _score = 0, _left = _dur, _combo = 0, _bestCombo = 0;
  bool _running = false, _flash = false;
  Timer? _timer;
  int _wordIdx = 0; // 표시되는 글자(텍스트)
  int _colorIdx = 0; // 그 글자의 실제 잉크 색
  bool _fake = false; // true면 "글자 뜻"의 색을 골라야 함
  List<int> _choices = [];

  // 초반 3색 → 후반 7색
  int get _activeCount => min(_colors.length, 3 + (_dur - _left) ~/ 4);
  int get _answer => _fake ? _wordIdx : _colorIdx;

  void _start() {
    _score = 0;
    _left = _dur;
    _combo = 0;
    _bestCombo = 0;
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
    final active = _activeCount;
    _wordIdx = _rng.nextInt(active);
    _colorIdx = _rng.nextInt(active);
    _fake = _rng.nextInt(5) == 0; // 20% 페이크 문제
    _choices = List.generate(active, (i) => i)..shuffle(_rng);
  }

  void _pick(int c) {
    if (!_running) return;
    setState(() {
      if (c == _answer) {
        _combo++;
        if (_combo > _bestCombo) _bestCombo = _combo;
        var gain = _combo >= 5 ? 20 : 10; // 5콤보부터 x2점
        if (_combo % 10 == 0) {
          gain += 50; // 10콤보 보너스
          _flash = true;
          Timer(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _flash = false);
          });
        }
        _score += gain;
      } else {
        _score = max(0, _score - 5);
        _combo = 0;
      }
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
      appBar: AppBar(title: Text('색깔 맞추기 🎨  ⏱️$_left  ⭐$_score  🔥$_combo')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '점수 $_score 🎉\n최고 콤보 $_bestCombo' : '글자의 "색깔"과 같은 버튼 누르기!\n📢페이크 땐 글자 "뜻"의 색 · 🔥콤보 보너스', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: _flash ? const Color(0xFFFFF59D) : Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _fake ? const Color(0xFFFFE0B2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _fake ? '📢 페이크! 글자 "뜻"의 색!' : '↓ 이 글자의 "잉크 색"은?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _fake ? Colors.deepOrange : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_names[_wordIdx], style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: _colors[_colorIdx])),
                  if (_combo >= 5) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🔥 $_combo 콤보 · x2점!', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: _choices
                        .map((c) => GestureDetector(
                              onTap: () => _pick(c),
                              child: Container(width: 64, height: 64, decoration: BoxDecoration(color: _colors[c], borderRadius: BorderRadius.circular(14))),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
