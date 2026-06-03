import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game_chrome.dart';

/// 반응속도: 빨강 화면이 초록으로 바뀌는 순간 탭! 빠를수록 고득점. (5라운드 합산)
/// ⚠️ 빨간 화면에서 탭하면 페널티(-100, 콤보 리셋) / 🔥 연속 성공 콤보 보너스(콤보×20).
class ReactionGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const ReactionGame({super.key, required this.onFinish});
  @override
  State<ReactionGame> createState() => _ReactionGameState();
}

enum _Phase { idle, waiting, go, tooSoon }

class _ReactionGameState extends State<ReactionGame> {
  _Phase _phase = _Phase.idle;
  int _round = 0;
  int _total = 0;
  int _lastMs = 0;
  int _combo = 0;
  int _bestCombo = 0;
  DateTime? _goAt;
  Timer? _timer;
  final _rng = Random();
  static const _rounds = 5;

  void _start() {
    setState(() {
      _round = 0;
      _total = 0;
      _lastMs = 0;
      _combo = 0;
      _bestCombo = 0;
    });
    _next();
  }

  void _next() {
    setState(() => _phase = _Phase.waiting);
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 1000 + _rng.nextInt(2500)), () {
      _goAt = DateTime.now();
      setState(() => _phase = _Phase.go);
    });
  }

  void _tap() {
    switch (_phase) {
      case _Phase.waiting:
        // 빨간 화면에서 탭 → 페널티 + 콤보 리셋, 같은 라운드 재시작
        _timer?.cancel();
        setState(() {
          _total = max(0, _total - 100);
          _combo = 0;
          _phase = _Phase.tooSoon;
        });
        break;
      case _Phase.go:
        final ms = DateTime.now().difference(_goAt!).inMilliseconds;
        _lastMs = ms;
        _combo++;
        if (_combo > _bestCombo) _bestCombo = _combo;
        _total += max(0, 600 - ms) + _combo * 20; // 빠를수록 ↑ + 연속 콤보 보너스
        _round++;
        if (_round >= _rounds) {
          setState(() => _phase = _Phase.idle);
          widget.onFinish(_total);
        } else {
          _next();
        }
        break;
      case _Phase.tooSoon:
        _next();
        break;
      case _Phase.idle:
        _start();
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    String text;
    switch (_phase) {
      case _Phase.idle:
        bg = Colors.blueGrey.shade100;
        text = _total > 0 ? '끝! 점수 $_total 🎉\n최고 콤보 $_bestCombo\n탭해서 다시' : '초록색이 되면\n최대한 빨리 탭!\n(빨강에서 누르면 -100)\n\n탭해서 시작';
        break;
      case _Phase.waiting:
        bg = Colors.red.shade400;
        text = '기다려...';
        break;
      case _Phase.go:
        bg = Colors.green.shade400;
        text = '지금 탭!';
        break;
      case _Phase.tooSoon:
        bg = Colors.orange.shade400;
        text = '너무 빨라요! -100\n탭해서 계속';
        break;
    }
    return Scaffold(
      appBar: AppBar(title: GameTitle('🟢  $_round/$_rounds  🔥$_combo')),
      body: GestureDetector(
        onTap: _tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(bg, Colors.white, 0.18)!, bg, Color.lerp(bg, Colors.black, 0.12)!],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                if (_lastMs > 0 && _phase == _Phase.waiting) Padding(padding: const EdgeInsets.only(top: 12), child: Text('직전 $_lastMs ms')),
                if (_combo >= 2 && _phase == _Phase.go) Padding(padding: const EdgeInsets.only(top: 12), child: Text('🔥 $_combo 콤보!', style: const TextStyle(fontSize: 18, color: Colors.white))),
                Padding(padding: const EdgeInsets.only(top: 12), child: Text('누적 $_total', style: const TextStyle(fontSize: 16))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
