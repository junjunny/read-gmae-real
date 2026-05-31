import 'package:flutter/material.dart';

import '../services/points_service.dart';
import '../services/session_prefs.dart';

/// 상품 현황 + 랜덤박스(100포인트로 1개).
/// 실제 상품/확률은 추후 확정 — 지금은 임시 풀로 동작.
class PrizeScreen extends StatefulWidget {
  const PrizeScreen({super.key});
  @override
  State<PrizeScreen> createState() => _PrizeScreenState();
}

class _PrizeScreenState extends State<PrizeScreen> {
  final _svc = PointsService();
  bool _opening = false;

  // 임시 상품 풀 (추후 확률과 함께 교체 예정)
  static const _samplePrizes = [
    '커피 기프티콘 ☕', '디저트 한 입 🍰', '안아주기 쿠폰 🤗',
    '소원권 1회 ✨', '치킨 한 마리 🍗', '꽝! 다음 기회에 🥲',
  ];

  Future<void> _openBox() async {
    final uid = SessionPrefs.userId ?? '0421';
    setState(() => _opening = true);
    try {
      final ok = await _svc.spend(uid, 100);
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('포인트가 부족해요 (100p 필요)')));
        return;
      }
      // 임시 추첨 (seed 기반)
      final seed = DateTime.now().microsecondsSinceEpoch;
      final prize = _samplePrizes[seed % _samplePrizes.length];
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('🎁 랜덤박스 결과'),
            content: Text(prize, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

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
          final canOpen = mine >= 100;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ptCard('주니', pts['0421'] ?? 0),
                  _ptCard('히수', pts['0118'] ?? 0),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('🎁 랜덤박스', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('100 포인트로 1개 열 수 있어요', style: TextStyle(color: Colors.grey)),
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
                          label: Text(canOpen ? '랜덤박스 열기 (-100p)' : '100p 모으면 열려요'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('상품 목록 (임시)', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('☕ 커피  ·  🍰 디저트  ·  🤗 안아주기  ·  ✨ 소원권  ·  🍗 치킨  ·  🥲 꽝', style: TextStyle(height: 1.6)),
                      SizedBox(height: 8),
                      Text('※ 실제 상품과 확률은 정해지면 반영할게요!', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
