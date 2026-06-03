import 'package:flutter/material.dart';

import '../games/apple_game.dart';
import '../games/avocado_game.dart';
import '../games/breakout_game.dart';
import '../games/bubble_game.dart';
import '../games/color_game.dart';
import '../games/dart_game.dart';
import '../games/flappy_game.dart';
import '../games/game_2048.dart';
import '../games/knife_game.dart';
import '../games/memory_game.dart';
import '../games/reaction_game.dart';
import '../games/schulte_game.dart';
import '../games/sniper_game.dart';
import '../games/snake_game.dart';
import '../games/stack_game.dart';
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
  _GameDef('dart', '다트 게임 🎯', '흔들리는 과녁 중앙 노리기! 10발·🔥불스아이 콤보', (f) => DartGame(onFinish: f)),
  _GameDef('avocado', '아보카도 점프 🥑', '발판 밟고 높이! 🌀스프링·🟥부서짐·⭐무적', (f) => AvocadoGame(onFinish: f)),
  _GameDef('knife', '나이프 던지기 🔪', '회전 통나무에 칼 꽂기! 부딪히면 끝·🍎보너스', (f) => KnifeGame(onFinish: f)),
  _GameDef('reaction2', '반응속도 🟢', '초록 되면 빨리! 빨강 누르면 페널티·🔥콤보', (f) => ReactionGame(onFinish: f)),
  _GameDef('schulte', '순서 터치 🔢', '1→25 순서대로 빨리', (f) => SchulteGame(onFinish: f)),
  _GameDef('color2', '색깔 맞추기 🎨', '글자의 잉크색! 3→7색·🔥콤보 x2/보너스', (f) => ColorGame(onFinish: f)),
  _GameDef('tetris2', '테트리스 🧱', '줄 지워서 점수(가속) · 홀드 추가', (f) => TetrisGame(onFinish: f)),
  _GameDef('g2048', '2048 🔢', '밀어서 숫자 합치기', (f) => Game2048(onFinish: f)),
  _GameDef('memory2', '카드 짝맞추기 🃏', '12쌍! 🃏조커 · 🔥연속 콤보', (f) => MemoryGame(onFinish: f)),
  _GameDef('whack2', '두더지 잡기 🔨', '👑황금 두더지 x3 · 💣폭탄 -3', (f) => WhackGame(onFinish: f)),
  _GameDef('snake2', '스네이크 🐍', '점점 빨라짐 · 🐢스페셜 먹이 감속', (f) => SnakeGame(onFinish: f)),
  _GameDef('sniper2', '저격수 🎯', '타겟 점점 작아짐 · 👑황금 x3', (f) => SniperGame(onFinish: f)),
  _GameDef('stack2', '블록 쌓기 🏗️', '정확히! ✨퍼펙트 보너스', (f) => StackGame(onFinish: f)),
  _GameDef('flappy', '플래피버드 🐦', '탭해서 파이프 통과 · ⭐무적 · ↔️간격', (f) => FlappyGame(onFinish: f)),
  _GameDef('breakout', '벽돌깨기 🧱', '공 튕겨 벽돌! 💥x2 · ➕분열 · 🧲자석', (f) => BreakoutGame(onFinish: f)),
  _GameDef('bubble', '버블슈터 🫧', '같은 색 3개+ 매치 · 🌈레인보우(닿는 색 다 제거)', (f) => BubbleGame(onFinish: f)),
  _GameDef('apple', '사과게임 🍎', '드래그로 합 10! 👑황금 · ⏰+10초', (f) => AppleGame(onFinish: f)),
];

/// 미니게임: 하루 동안 베스트 점수 갱신 → 자정(KST)에 자동 정산
/// (둘 다 한 게임은 승+10/패-5, 한 명만 한 게임은 참여자만 +10).
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
                      child: Text('🌙 오늘 하루 계속 도전해서 베스트 점수를 올리세요!\n자정에 게임별 정산: 둘 다 했으면 높은 점수 +10 / 낮은 점수 -5.\n한 명만 한 게임은 참여자만 +10 (안 해도 감점 없음)!',
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

  // 실시간 승자(오늘 베스트가 더 높은 사람). 동점/둘 다 무기록이면 승자 없음.
  bool get _hasAny => s1 != null || s2 != null;
  bool get _win1 => _hasAny && (s1 ?? -1) > (s2 ?? -1);
  bool get _win2 => _hasAny && (s2 ?? -1) > (s1 ?? -1);

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
                _chip('주니', s1, _win1),
                const Text('오늘 베스트', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _chip('히수', s2, _win2),
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

  Widget _chip(String name, int? v, bool winning) => Column(
        children: [
          _highlightName(name, winning),
          Text(v?.toString() ?? '-', style: TextStyle(fontSize: 18, fontWeight: winning ? FontWeight.bold : FontWeight.normal)),
        ],
      );

  // 승자 이름에 형광펜 스타일 하이라이트
  Widget _highlightName(String name, bool winning) {
    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
    if (!winning) return text;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 형광펜 자국(글자 아래쪽을 덮는 노란 마커, 살짝 기울임)
        Positioned(
          left: -2,
          right: -2,
          bottom: 2,
          height: 13,
          child: Transform.rotate(
            angle: -0.025,
            child: Container(
              decoration: BoxDecoration(color: const Color(0xCCFFEE58), borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        text,
      ],
    );
  }

  Future<void> _play(BuildContext context) async {
    final uid = SessionPrefs.userId ?? '0421';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => def.builder((score) async {
        try {
          await svc.submitBest(def.key, uid, score);
          final newRecord = await svc.updateRecord(def.key, uid, score);
          // 월드레코드 갱신했을 때만 하단 알림. 그 외엔 각 게임의 중앙 점수 화면으로만 안내.
          if (context.mounted && newRecord) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('🏆 월드레코드 갱신! ${nickOf(uid)} $score점 — 즉시 +100P!')),
            );
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
