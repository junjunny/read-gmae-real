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
  final double pct; // 확률(%)
  final String emoji; // 타입
  const _Prize(this.name, this.pct, this.emoji);
}

const int kBoxCost = 1000;
// 확률 합 = 100.0% (내림차순). 비싼 상품은 희귀하게 유지.
const List<_Prize> _kPrizes = [
  _Prize('꼭 안아주기 쿠폰 (5분)', 11, '💆'),
  _Prize('편의점 1,000원', 11, '💸'),
  _Prize('칭찬 문자 5개 보내주기', 9.8, '💌'),
  _Prize('아아 1잔 (2,000원)', 9, '💸'),
  _Prize('마사지 10분권', 9, '💆'),
  _Prize('같이 산책 30분 (코스 상대방이 고름)', 9, '🎬'),
  _Prize('같이 영화 1편 (상대방이 고름)', 9, '🎬'),
  _Prize('추억사진 골라 그때 경험 손편지 쓰기', 8, '💌'),
  _Prize('스킨케어 해주기 (팩+마사지)', 6, '💆'),
  _Prize('쿠키/바스크 치즈케이크 만들어주기', 5, '🍳'),
  _Prize('기프티콘 5,000원', 5, '💸'),
  _Prize('데이트 코스 풀기획', 4, '🎬'),
  _Prize('마사지 20분권', 2, '💆'),
  _Prize('기프티콘 10,000원', 2, '💸'),
  _Prize('뮤지컬/콘서트 티켓 (200,000원)', 0.2, '💸'),
];

class _PrizeScreenState extends State<PrizeScreen> {
  final _svc = PointsService();
  final _rng = Random();
  bool _opening = false;

  // 11.0 → '11', 9.8 → '9.8' 처럼 깔끔하게 표시.
  static String _pctText(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

  // 확률 합(=100%) 기준으로 비율대로 추첨.
  _Prize _draw() {
    final total = _kPrizes.fold<double>(0, (a, p) => a + p.pct);
    final r = _rng.nextDouble() * total;
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
                Text('${prize.emoji} 당첨!', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Text('🎉 ${prize.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                              Text('${p.emoji} '),
                              Expanded(child: Text(p.name)),
                              Text('${_pctText(p.pct)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6F91))),
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
