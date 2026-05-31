import 'dart:math';

import 'package:flutter/material.dart';

import '../services/points_service.dart';
import '../services/session_prefs.dart';

/// 상품 현황 + 랜덤박스(1,000포인트로 1개, 확률 추첨).
class PrizeScreen extends StatefulWidget {
  const PrizeScreen({super.key});
  @override
  State<PrizeScreen> createState() => _PrizeScreenState();
}

class _Prize {
  final String name;
  final int price;
  final double pct; // 확률(%)
  const _Prize(this.name, this.price, this.pct);
}

const int kBoxCost = 1000;
const List<_Prize> _kPrizes = [
  _Prize('뮤지컬/콘서트 티켓', 200000, 0.5),
  _Prize('기프티콘', 20000, 5.0),
  _Prize('기프티콘', 5000, 14.5),
  _Prize('아아 1잔', 2000, 35.0),
  _Prize('편의점 상품', 1000, 45.0),
];

class _PrizeScreenState extends State<PrizeScreen> {
  final _svc = PointsService();
  final _rng = Random();
  bool _opening = false;

  _Prize _draw() {
    final r = _rng.nextDouble() * 100;
    var acc = 0.0;
    for (final p in _kPrizes) {
      acc += p.pct;
      if (r < acc) return p;
    }
    return _kPrizes.last;
  }

  Future<void> _openBox() async {
    final uid = SessionPrefs.userId ?? '0421';
    setState(() => _opening = true);
    try {
      final ok = await _svc.spend(uid, kBoxCost);
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('포인트가 부족해요 (1,000P 필요)')));
        return;
      }
      final prize = _draw();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('🎁 랜덤박스 결과'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎉 ${prize.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('(${_won(prize.price)})', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  static String _won(int v) => '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 현황 🎁')),
      body: StreamBuilder<Map<String, int>>(
        stream: _svc.watchPoints(),
        builder: (context, snap) {
          final pts = snap.data ?? {'0421': 0, '0118': 0};
          final uid = SessionPrefs.userId ?? '0421';
          final mine = pts[uid] ?? 0;
          final canOpen = mine >= kBoxCost;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [_ptCard('주니', pts['0421'] ?? 0), _ptCard('히수', pts['0118'] ?? 0)],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('🎁 랜덤박스', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('1,000 포인트로 1개', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text('내 포인트: $mine', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (canOpen && !_opening) ? _openBox : null,
                          icon: _opening
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.card_giftcard),
                          label: Text(canOpen ? '랜덤박스 열기 (-1,000P)' : '1,000P 모으면 열려요'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎰 상품 & 확률', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...List.generate(_kPrizes.length, (i) {
                        final p = _kPrizes[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('${p.name}  (${_won(p.price)})')),
                              Text('${p.pct}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6F91))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ptCard(String name, int pt) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$pt P', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}
