import 'package:flutter/material.dart';

import '../games/apple_game.dart';
import '../games/blast_game.dart';
import '../games/breakout_game.dart';
import '../games/bubble_game.dart';
import '../games/color_game.dart';
import '../games/flappy_game.dart';
import '../games/game_2048.dart';
import '../games/memory_game.dart';
import '../games/reaction_game.dart';
import '../games/schulte_game.dart';
import '../games/sniper_game.dart';
import '../games/snake_game.dart';
import '../games/stack_game.dart';
import '../games/tap_game.dart';
import '../games/tetris_game.dart';
import '../games/whack_game.dart';
import '../services/points_service.dart';
import '../services/session_prefs.dart';
import '../util/users.dart';

typedef GameBuilder = Widget Function(void Function(int score) onFinish);

class _GameDef {
  final String key, title, desc;
  final GameBuilder builder;
  const _GameDef(this.key, this.title, this.desc, this.builder);
}

// ⚠️ 게임 내용이 바뀐 종목은 key 뒤에 버전(2)을 붙여 월드레코드를 새로 시작합니다.
//    (내용이 그대로인 순서터치·2048만 기존 key 유지 → 기록 보존)
final List<_GameDef> _kGames = [
  _GameDef('taptap2', '빠른 탭 ⚡', '15초! ⭐황금 탭 x2 · 🔥콤보 보너스', (f) => TapGame(onFinish: f)),
  _GameDef('reaction2', '반응속도 🟢', '초록 되면 빨리! 빨강 누르면 페널티·🔥콤보', (f) => ReactionGame(onFinish: f)),
  _GameDef('schulte', '순서 터치 🔢', '1→25 순서대로 빨리', (f) => SchulteGame(onFinish: f)),
  _GameDef('color2', '색깔 맞추기 🎨', '3→7색·📢페이크·🔥콤보 x2/보너스', (f) => ColorGame(onFinish: f)),
  _GameDef('tetris2', '테트리스 🧱', '줄 지워서 점수(가속) · 홀드 추가', (f) => TetrisGame(onFinish: f)),
  _GameDef('g2048', '2048 🔢', '밀어서 숫자 합치기', (f) => Game2048(onFinish: f)),
  _GameDef('memory2', '카드 짝맞추기 🃏', '16쌍! 🃏조커 · 🔥연속 콤보', (f) => MemoryGame(onFinish: f)),
  _GameDef('whack2', '두더지 잡기 🔨', '👑황금 두더지 x3 · 💣폭탄 -3', (f) => WhackGame(onFinish: f)),
  _GameDef('snake2', '스네이크 🐍', '점점 빨라짐 · 🐢스페셜 먹이 감속', (f) => SnakeGame(onFinish: f)),
  _GameDef('sniper2', '저격수 🎯', '타겟 점점 작아짐 · 👑황금 x3', (f) => SniperGame(onFinish: f)),
  _GameDef('stack2', '블록 쌓기 🏗️', '정확히! ✨퍼펙트 보너스', (f) => StackGame(onFinish: f)),
  _GameDef('flappy', '플래피버드 🐦', '탭해서 파이프 통과 · ⭐무적 · ↔️간격', (f) => FlappyGame(onFinish: f)),
  _GameDef('breakout', '벽돌깨기 🧱', '공 튕겨 벽돌! 💥x2 · ➕분열 · 🧲자석', (f) => BreakoutGame(onFinish: f)),
  _GameDef('bubble', '버블슈터 🫧', '같은 색 3개+ · 💣폭탄 · 🌈레인보우', (f) => BubbleGame(onFinish: f)),
  _GameDef('blast', '블록 블라스트 🟦', '줄 채우기! 🔥2줄 x1.5 · 🌟와일드', (f) => BlastGame(onFinish: f)),
  _GameDef('apple', '사과게임 🍎', '드래그로 합 10! 👑황금 · ⏰+10초', (f) => AppleGame(onFinish: f)),
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
          final newRecord = await svc.updateRecord(def.key, uid, score);
          if (context.mounted) {
            final msg = newRecord
                ? '🏆 월드레코드 갱신! ${nickOf(uid)} $score점 — 즉시 +100P!'
                : '${nickOf(uid)} 점수 $score — 오늘 베스트 반영!';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
