import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 카드 짝맞추기: 12쌍(24장)을 뒤집어 짝 맞추기. 빠를수록 + 콤보 이어갈수록 고득점.
/// 🃏 조커 카드 짝은 보너스(+200) / 🔥 연속 성공 콤보(콤보×10 추가점).
class MemoryGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const MemoryGame({super.key, required this.onFinish});
  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

// 11종 + 조커(🃏) = 12쌍(24장)
const _emojis = ['🍎', '🐶', '⭐', '🌸', '🍕', '🎈', '🐱', '🚀', '🍉', '🐢', '🌈'];
const _joker = '🃏';

class _MemoryGameState extends State<MemoryGame> {
  List<String> _cards = [];
  final Set<int> _matched = {};
  final List<int> _flipped = [];
  int _tries = 0;
  int _score = 0;
  int _combo = 0, _bestCombo = 0;
  bool _busy = false;
  bool _started = false;
  String? _fx;
  DateTime? _start;
  Timer? _ticker;
  int _elapsed = 0;

  void _begin() {
    _cards = [..._emojis, ..._emojis, _joker, _joker]..shuffle(Random());
    _matched.clear();
    _flipped.clear();
    _tries = 0;
    _score = 0;
    _combo = 0;
    _bestCombo = 0;
    _fx = null;
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
        _combo++;
        if (_combo > _bestCombo) _bestCombo = _combo;
        final isJoker = _cards[a] == _joker;
        final gain = (isJoker ? 200 : 50) + _combo * 10;
        await Future.delayed(const Duration(milliseconds: 280));
        setState(() {
          _matched.addAll([a, b]);
          _flipped.clear();
          _busy = false;
          _score += gain;
          _fx = isJoker ? '🃏 조커! +$gain' : '🔥 $_combo콤보 +$gain';
        });
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _fx = null);
        });
        if (_matched.length == _cards.length) _finish();
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() {
          _flipped.clear();
          _busy = false;
          _combo = 0; // 콤보 리셋
        });
      }
    }
  }

  void _finish() {
    _ticker?.cancel();
    final sec = DateTime.now().difference(_start!).inSeconds;
    // 빠르고 적게 틀릴수록 ↑ 시간/시도 보너스
    final timeBonus = max(0, 1600 - sec * 7 - (_tries - 12) * 16);
    _score += timeBonus;
    _started = false;
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('카드 짝맞추기 🃏  ⏱️${_elapsed}s  ⭐$_score  🔥$_combo')),
      body: !_started
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '완성! 점수 $_score 🎉\n최고 콤보 $_bestCombo' : '같은 카드 12쌍을 빨리 맞춰요!\n🃏조커 짝은 보너스 · 🔥콤보 이어가기', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _begin, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: _cards.length,
                    itemBuilder: (_, i) {
                      final show = _flipped.contains(i) || _matched.contains(i);
                      final isJoker = _cards[i] == _joker;
                      return GestureDetector(
                        onTap: () => _tap(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _matched.contains(i)
                                ? (isJoker ? Colors.amber.shade100 : Colors.green.shade100)
                                : (show ? Colors.white : Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: show && isJoker ? Colors.amber : Colors.grey.shade300, width: show && isJoker ? 2 : 1),
                          ),
                          child: Center(child: Text(show ? _cards[i] : '?', style: TextStyle(fontSize: 26, color: show ? null : Colors.white))),
                        ),
                      );
                    },
                  ),
                ),
                if (_fx != null)
                  Align(
                    alignment: const Alignment(0, -0.9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                      child: Text(_fx!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
              ],
            ),
    );
  }
}
