import 'package:flutter/material.dart';

import '../games/color_game.dart';
import '../games/math_game.dart';
import '../games/reaction_game.dart';
import '../games/schulte_game.dart';
import '../games/simon_game.dart';
import '../games/tap_game.dart';
import '../games/tetris_game.dart';
import '../services/points_service.dart';
import '../services/session_prefs.dart';
import '../util/users.dart';

typedef GameBuilder = Widget Function(void Function(int score) onFinish);

class _GameDef {
  final String key, title, desc;
  final GameBuilder builder;
  const _GameDef(this.key, this.title, this.desc, this.builder);
}

final List<_GameDef> _kGames = [
  _GameDef('taptap', '빠른 탭 ⚡', '15초 동안 최대한 많이 탭', (f) => TapGame(onFinish: f)),
  _GameDef('reaction', '반응속도 🟢', '초록 되면 빨리 탭(5라운드)', (f) => ReactionGame(onFinish: f)),
  _GameDef('schulte', '순서 터치 🔢', '1→25 순서대로 빨리', (f) => SchulteGame(onFinish: f)),
  _GameDef('color', '색깔 맞추기 🎨', '글자의 "색"을 빠르게', (f) => ColorGame(onFinish: f)),
  _GameDef('math', '빠른 계산 🧮', '30초 암산 대결', (f) => MathGame(onFinish: f)),
  _GameDef('simon', '기억력 순서 🧠', '불빛 순서 따라하기', (f) => SimonGame(onFinish: f)),
  _GameDef('tetris', '테트리스 🧱', '줄 지워서 점수', (f) => TetrisGame(onFinish: f)),
];

/// 미니게임: 하루 동안 베스트 점수 갱신 → 자정(KST)에 자동 정산(승+10/패-5).
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = PointsService();
    return Scaffold(
      appBar: AppBar(title: const Text('미니게임 🎮')),
      body: StreamBuilder<Map<String, Map<String, int?>>>(
        stream: svc.watchTodayGames(),
        builder: (context, snap) {
          final today = snap.data ?? {};
          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: svc.watchRecords(),
            builder: (context, rSnap) {
              final records = rSnap.data ?? {};
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.indigo.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('🌙 오늘 하루 계속 도전해서 베스트 점수를 올리세요!\n자정에 게임별 정산: 높은 점수 +10 / 낮은 점수 -5.\n⚠️ 그 게임을 안 한 사람은 자동 패배(-5)!',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._kGames.map((g) {
                    final sc = today[g.key] ?? {};
                    return _GameCard(def: g, s1: sc['0421'], s2: sc['0118'], record: records[g.key], svc: svc);
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _GameDef def;
  final int? s1, s2;
  final Map<String, dynamic>? record;
  final PointsService svc;
  const _GameCard({required this.def, required this.s1, required this.s2, required this.record, required this.svc});

  @override
  Widget build(BuildContext context) {
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
                      Text(def.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(def.desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                FilledButton(onPressed: () => _play(context), child: const Text('플레이')),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _chip('주니', s1),
                const Text('오늘 베스트', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _chip('히수', s2),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8)),
              child: Text(
                record == null
                    ? '🏆 월드레코드: 아직 없음 — 첫 기록의 주인공이 되어보세요!'
                    : '🏆 월드레코드 ${record!['score']}점 · ${nickOf(record!['holder'] as String?)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String name, int? v) => Column(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(v?.toString() ?? '-', style: const TextStyle(fontSize: 18)),
        ],
      );

  Future<void> _play(BuildContext context) async {
    final uid = SessionPrefs.userId ?? '0421';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => def.builder((score) async {
        try {
          await svc.submitBest(def.key, uid, score);
          await svc.updateRecord(def.key, uid, score);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${nickOf(uid)} 점수 $score — 오늘 베스트 반영!')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('점수 저장 실패: $e'), duration: const Duration(seconds: 6)));
          }
        }
      }),
    ));
  }
}
