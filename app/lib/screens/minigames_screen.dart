import 'package:flutter/material.dart';

import '../games/tap_game.dart';
import '../services/points_service.dart';
import '../services/session_prefs.dart';
import '../util/users.dart';

/// 미니게임 목록 + 점수 공유/정산(승 +10, 패 -5).
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미니게임 🎮')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('둘이 같은 게임을 하고 "정산"하면\n높은 점수 +10, 낮은 점수 -5 💰',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          const _GameCard(
            gameKey: 'taptap',
            title: '빠른 탭 ⚡',
            desc: '15초 동안 최대한 많이 탭하기',
            ready: true,
          ),
          const _GameCard(gameKey: 'tetris', title: '테트리스 🧱', desc: '준비 중', ready: false),
          const _GameCard(gameKey: 'spotdiff', title: '틀린 그림 찾기 🔍', desc: '준비 중', ready: false),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String gameKey, title, desc;
  final bool ready;
  const _GameCard({required this.gameKey, required this.title, required this.desc, required this.ready});

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
                if (ready)
                  FilledButton(
                    onPressed: () => _play(context, svc),
                    child: const Text('플레이'),
                  )
                else
                  const Chip(label: Text('곧')),
              ],
            ),
            if (ready) ...[
              const Divider(),
              StreamBuilder<Map<String, int?>>(
                stream: svc.watchGame(gameKey),
                builder: (context, snap) {
                  final m = snap.data ?? {};
                  final s1 = m['0421'];
                  final s2 = m['0118'];
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _scoreChip('주니', s1),
                          _scoreChip('히수', s2),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (s1 != null && s2 != null)
                              ? () async {
                                  final msg = await svc.settle(gameKey);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.emoji_events),
                          label: const Text('정산하기 (승+10 / 패-5)'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
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
      builder: (_) => TapGame(
        onFinish: (score) async {
          await svc.submitScore(gameKey, uid, score);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${nickOf(uid)} 점수 $score 등록! 둘 다 하면 정산하세요.')),
            );
          }
        },
      ),
    ));
  }
}
