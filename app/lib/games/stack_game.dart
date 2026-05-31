import 'dart:async';

import 'package:flutter/material.dart';

/// 블록 쌓기: 좌우로 움직이는 블록을 탭해서 떨어뜨려 쌓기. 어긋난 만큼 잘려나감.
/// 안 겹치면 끝. 높이 쌓을수록 고득점(점점 빨라짐).
class StackGame extends StatefulWidget {
  final void Function(int score) onFinish;
  const StackGame({super.key, required this.onFinish});
  @override
  State<StackGame> createState() => _StackGameState();
}

class _Block {
  double left, width; // 0~1
  _Block(this.left, this.width);
}

class _StackGameState extends State<StackGame> {
  final List<_Block> _stack = [];
  double _movLeft = 0;
  double _movWidth = 0.5;
  int _dir = 1;
  int _score = 0;
  bool _running = false;
  Timer? _loop;

  double get _speed => 0.012 + _score * 0.0012;

  void _start() {
    _stack.clear();
    _stack.add(_Block(0.25, 0.5)); // 바닥
    _movWidth = 0.5;
    _movLeft = 0;
    _dir = 1;
    _score = 0;
    _running = true;
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    setState(() {});
  }

  void _tick() {
    if (!_running) return;
    _movLeft += _dir * _speed;
    if (_movLeft <= 0) {
      _movLeft = 0;
      _dir = 1;
    } else if (_movLeft + _movWidth >= 1) {
      _movLeft = 1 - _movWidth;
      _dir = -1;
    }
    setState(() {});
  }

  void _drop() {
    if (!_running) return;
    final prev = _stack.last;
    final l = _movLeft > prev.left ? _movLeft : prev.left;
    final r = (_movLeft + _movWidth) < (prev.left + prev.width) ? (_movLeft + _movWidth) : (prev.left + prev.width);
    final overlap = r - l;
    if (overlap <= 0.005) {
      _end(); // 빗나감
      return;
    }
    _stack.add(_Block(l, overlap));
    _score++;
    _movWidth = overlap;
    _movLeft = 0;
    _dir = 1;
    setState(() {});
  }

  void _end() {
    _running = false;
    _loop?.cancel();
    setState(() {});
    widget.onFinish(_score);
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('블록 쌓기 🏗️   $_score')),
      body: !_running
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_score > 0 ? '와르르! $_score층 쌓음 🏗️' : '움직이는 블록을 탭해서\n정확히 쌓아올리세요!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _start, child: Text(_score > 0 ? '다시' : '시작')),
              ]),
            )
          : GestureDetector(
              onTapDown: (_) => _drop(),
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth;
                const blockH = 26.0;
                // 최근 14층만 그려서 위로 쌓이는 느낌
                final visible = _stack.length > 14 ? _stack.sublist(_stack.length - 14) : _stack;
                return Container(
                  color: const Color(0xFFEAF2FB),
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      for (var i = 0; i < visible.length; i++)
                        Positioned(
                          left: visible[i].left * w,
                          bottom: i * blockH,
                          width: visible[i].width * w,
                          height: blockH - 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color.lerp(const Color(0xFFFF6F91), const Color(0xFF42A5F5), (i / 14))!,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      // 움직이는 블록 (맨 위)
                      Positioned(
                        left: _movLeft * w,
                        bottom: visible.length * blockH,
                        width: _movWidth * w,
                        height: blockH - 2,
                        child: Container(decoration: BoxDecoration(color: const Color(0xFFFFB300), borderRadius: BorderRadius.circular(4))),
                      ),
                      const Align(alignment: Alignment(0, -0.85), child: Text('화면을 탭해서 떨어뜨리기', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}
