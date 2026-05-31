import 'package:flutter/material.dart';

import '../games/spot_difference_game.dart';
import '../games/tap_game.dart';
import '../games/tetris_game.dart';
import '../services/points_service.dart';
import '../services/session_prefs.dart';
import '../util/users.dart';

/// 미니게임: 각자 플레이 → 둘 다 점수 모이면 자동 정산(승 +10, 패 -5).
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미니게임 🎮')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('둘 다 같은 게임을 플레이하면 자동 정산!\n높은 점수 +10, 낮은 점수 -5 💰', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          _GameCard(
            gameKey: 'taptap',
            title: '빠른 탭 ⚡',
            desc: '15초 동안 최대한 많이 탭',
            builder: (onFinish) => TapGame(onFinish: onFinish),
          ),
          _GameCard(
            gameKey: 'tetris',
            title: '테트리스 🧱',
            desc: '줄을 지워 점수 획득',
            builder: (onFinish) => TetrisGame(onFinish: onFinish),
          ),
          _GameCard(
            gameKey: 'spotdiff',
            title: '틀린 그림 찾기 🔍',
            desc: '다른 곳 5개를 찾아라',
            builder: (onFinish) => SpotDifferenceGame(onFinish: onFinish),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String gameKey, title, desc;
  final Widget Function(void Function(int score) onFinish) builder;
  const _GameCard({required this.gameKey, required this.title, required this.desc, required this.builder});

  @override
  Widget build(BuildContext context) {
    final svc = PointsService();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                FilledButton(onPressed: () => _play(context, svc), child: const Text('플레이')),
              ],
            ),
            const Divider(),
            StreamBuilder<Map<String, dynamic>>(
              stream: svc.watchGame(gameKey),
              builder: (context, snap) {
                final m = snap.data ?? {};
                final s1 = m['0421'] as int?;
                final s2 = m['0118'] as int?;
                final last = m['lastResult'] as String?;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _scoreChip('주니', s1),
                        _scoreChip('히수', s2),
                      ],
                    ),
                    if (s1 != null && s2 == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('히수가 플레이하면 자동 정산돼요', style: TextStyle(fontSize: 12, color: Colors.orange))),
                    if (s2 != null && s1 == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('주니가 플레이하면 자동 정산돼요', style: TextStyle(fontSize: 12, color: Colors.orange))),
                    if (last != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('🏁 $last', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreChip(String name, int? score) => Column(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(score?.toString() ?? '-', style: const TextStyle(fontSize: 20)),
        ],
      );

  Future<void> _play(BuildContext context, PointsService svc) async {
    final uid = SessionPrefs.userId ?? '0421';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => builder((score) async {
        final msg = await svc.submitScoreAuto(gameKey, uid, score);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${nickOf(uid)}: $msg')));
        }
      }),
    ));
  }
}
