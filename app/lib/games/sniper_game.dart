import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 저격수 🎯: 움직이는 타겟을 빠르게 탭! 25초 동안 최대한 많이 맞히기.
/// 진행할수록 더 자주, 더 빠르게 나타남. 놓친 타겟은 화면 밖으로 사라짐.
class SniperGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const SniperGame({super.key, required this.onFinish});
  @override
  State<SniperGame> createState() => _SniperGameState();
}

class _Target {
  double x, y; // 0~1 (정규화)
  double vx, vy; // 초당 이동(정규화)
  double r; // 반지름(짧은 변 대비 비율)
  final int id;
  _Target(this.id, this.x, this.y, this.vx, this.vy, this.r);
}

class _SniperGameState extends State<SniperGame> {
  final _rng = Random();
  final List<_Target> _targets = [];
  int _score = 0, _left = 25, _nextId = 0;
  bool _running = false;
  Timer? _loop, _spawnTimer, _clock;
  static const _frame = Duration(milliseconds: 33);

  void _start() {
    _targets.clear();
    _score = 0;
    _left = 25;
    _running = true;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    _loop?.cancel();
    _loop = Timer.periodic(_frame, (_) => _tick());
    _spawn();
    setState(() {});
  }

  int get _elapsed => 25 - _left;
  int get _spawnGapMs => max(420, 1000 - _elapsed * 25); // 점점 자주
  double get _speedMul => 1.0 + _elapsed * 0.05; // 점점 빠르게

  void _spawn() {
    if (!_running) return;
    // 가장자리에서 등장 → 반대편으로 이동
    final fromLeft = _rng.nextBool();
    final vertical = _rng.nextBool();
    double x, y, vx, vy;
    final speed = (0.18 + _rng.nextDouble() * 0.22) * _speedMul; // 초당
    if (vertical) {
      x = 0.12 + _rng.nextDouble() * 0.76;
      y = fromLeft ? -0.1 : 1.1;
      vx = (_rng.nextDouble() - 0.5) * 0.15;
      vy = fromLeft ? speed : -speed;
    } else {
      y = 0.12 + _rng.nextDouble() * 0.76;
      x = fromLeft ? -0.1 : 1.1;
      vx = fromLeft ? speed : -speed;
      vy = (_rng.nextDouble() - 0.5) * 0.15;
    }
    final r = 0.07 + _rng.nextDouble() * 0.03; // 살짝 크기 차이
    _targets.add(_Target(_nextId++, x, y, vx, vy, r));

    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _spawnGapMs), _spawn);
  }

  void _tick() {
    if (!_running) return;
    const dt = 0.033;
    for (final t in _targets) {
      t.x += t.vx * dt;
      t.y += t.vy * dt;
    }
    _targets.removeWhere((t) => t.x < -0.2 || t.x > 1.2 || t.y < -0.2 || t.y > 1.2);
    setState(() {});
  }

  void _hit(_Target t) {
    if (!_running) return;
    setState(() {
      _score++;
      _targets.remove(t);
    });
  }

  void _end() {
    _running = false;
    _loop?.cancel();
    _spawnTimer?.cancel();
    _clock?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _spawnTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('저격수 🎯   ⏱️$_left  ⭐$_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 || _left == 0 ? '명중 $_score발! 🎯' : '움직이는 타겟(🎯)을\n빠르게 탭! 25초 동안 최대한 많이!',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: const Text('시작')),
              ]),
            )
          : LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final unit = min(w, h);
              return Container(
                color: const Color(0xFF0D1B2A),
                child: Stack(
                  children: [
                    for (final t in _targets)
                      Positioned(
                        left: t.x * w - t.r * unit,
                        top: t.y * h - t.r * unit,
                        width: t.r * 2 * unit,
                        height: t.r * 2 * unit,
                        child: GestureDetector(
                          onTapDown: (_) => _hit(t),
                          child: const _TargetDot(),
                        ),
                      ),
                  ],
                ),
              );
            }),
    );
  }
}

class _TargetDot extends StatelessWidget {
  const _TargetDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE53935)),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: const Center(
                child: FittedBox(child: Padding(padding: EdgeInsets.all(2), child: Text('🎯', style: TextStyle(fontSize: 18)))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
