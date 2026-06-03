// 17개 미니게임 자동 플레이 테스트.
// 각 게임 위젯을 띄워 시작 → 탭/드래그/시간경과로 실제 조작하고,
// 예외 없이 동작하는지(테스트는 Flutter 에러 발생 시 자동 실패) + 점수/종료 콜백을 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grim_pingpong/games/apple_game.dart';
import 'package:grim_pingpong/games/avocado_game.dart';
import 'package:grim_pingpong/games/breakout_game.dart';
import 'package:grim_pingpong/games/bubble_game.dart';
import 'package:grim_pingpong/games/dart_game.dart';
import 'package:grim_pingpong/games/color_game.dart';
import 'package:grim_pingpong/games/flappy_game.dart';
import 'package:grim_pingpong/games/game_2048.dart';
import 'package:grim_pingpong/games/knife_game.dart';
import 'package:grim_pingpong/games/memory_game.dart';
import 'package:grim_pingpong/games/reaction_game.dart';
import 'package:grim_pingpong/games/schulte_game.dart';
import 'package:grim_pingpong/games/snake_game.dart';
import 'package:grim_pingpong/games/sniper_game.dart';
import 'package:grim_pingpong/games/stack_game.dart';
import 'package:grim_pingpong/games/tetris_game.dart';
import 'package:grim_pingpong/games/whack_game.dart';

void main() {
  // 큰 화면으로 고정(게임들이 화면 크기를 사용)
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> mount(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: game));
    await tester.pump();
  }

  Future<void> tapStart(WidgetTester tester) async {
    final s = find.text('시작');
    if (s.evaluate().isNotEmpty) {
      await tester.tap(s);
      await tester.pump();
    }
  }

  // 테스트 종료 시 위젯을 떼어내 타이머 정리
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('① 나이프 던지기: 시작→던지기 반복', (tester) async {
    var finished = false;
    await mount(tester, KnifeGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    // 칼 여러 번 던지기(통나무 회전 중, 충돌하면 종료될 수 있음)
    for (var i = 0; i < 25 && !finished; i++) {
      await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('🔪'), findsWidgets); // 상단바에 로고+점수만 표시
    await teardown(tester);
  });

  testWidgets('② 반응속도: 5라운드 초록 탭 → 종료', (tester) async {
    var finished = false;
    await mount(tester, ReactionGame(onFinish: (s) => finished = true));
    // 화면 탭으로 시작
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    for (var r = 0; r < 6 && !finished; r++) {
      await tester.pump(const Duration(seconds: 4)); // 초록(go) 보장
      if (!finished) {
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
      }
    }
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('③ 순서 터치: 1→25 순서대로 → 종료', (tester) async {
    var finished = false;
    int? sc;
    await mount(tester, SchulteGame(onFinish: (s) {
      finished = true;
      sc = s;
    }));
    await tapStart(tester);
    for (var n = 1; n <= 25; n++) {
      await tester.tap(find.text('$n'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finished, isTrue);
    expect(sc, isNotNull);
    await teardown(tester);
  });

  testWidgets('④ 색깔 맞추기: 버튼 탭 + 22초 후 종료', (tester) async {
    var finished = false;
    await mount(tester, ColorGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    for (var i = 0; i < 5; i++) {
      final choices = find.byType(GestureDetector);
      if (choices.evaluate().isNotEmpty) await tester.tap(choices.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 23));
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑤ 테트리스: 시작→홀드→하드드롭 반복 → 게임오버', (tester) async {
    var finished = false;
    await mount(tester, TetrisGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    // 홀드 1회
    final hold = find.text('홀드');
    if (hold.evaluate().isNotEmpty) {
      await tester.tap(hold);
      await tester.pump();
    }
    for (var i = 0; i < 160 && !finished; i++) {
      await tester.tap(find.byIcon(Icons.arrow_downward), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑥ 2048: 스와이프 이동 다수 → 크래시 없이 진행', (tester) async {
    var finished = false;
    await mount(tester, Game2048(onFinish: (s) => finished = true));
    await tapStart(tester);
    // 하단 버튼 제거 → 스와이프(플링)로만 이동
    const dirs = [Offset(-300, 0), Offset(0, -300), Offset(300, 0), Offset(0, 300)];
    for (var i = 0; i < 16 && !finished; i++) {
      await tester.fling(find.byType(GestureDetector).first, dirs[i % 4], 1000);
      await tester.pump(const Duration(milliseconds: 220)); // 슬라이드+합체 애니메이션 경과
    }
    // 보드/점수 표시가 살아있음(진행 중이면 상단바 1개, 게임오버면 +오버레이)
    expect(find.textContaining('점수'), findsWidgets);
    await teardown(tester);
  });

  testWidgets('⑦ 카드 짝맞추기: 카드 뒤집기 동작', (tester) async {
    await mount(tester, MemoryGame(onFinish: (s) {}));
    await tapStart(tester);
    final cards = find.byType(GestureDetector);
    expect(cards.evaluate().length, greaterThanOrEqualTo(16)); // 8쌍=16장
    await tester.tap(cards.at(0), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(cards.at(1), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1)); // 비교 애니메이션 해소
    await teardown(tester);
  });

  testWidgets('⑧ 두더지 잡기: 칸 탭 + 20초 후 종료', (tester) async {
    var finished = false;
    await mount(tester, WhackGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    for (var i = 0; i < 8; i++) {
      final holes = find.byType(GestureDetector);
      if (holes.evaluate().isNotEmpty) {
        await tester.tap(holes.at(i % holes.evaluate().length), warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 22)); // 종료 + 잔여 타이머 flush
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑨ 스네이크: 시작→직진→벽 충돌로 종료', (tester) async {
    var finished = false;
    await mount(tester, SnakeGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    await tester.pump(const Duration(seconds: 8)); // 위로 직진하다 벽 충돌
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑩ 저격수: 25초 후 종료', (tester) async {
    var finished = false;
    await mount(tester, SniperGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    await tester.pump(const Duration(seconds: 26));
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑪ 블록 쌓기: 탭으로 떨어뜨리기 반복 → 종료', (tester) async {
    var finished = false;
    await mount(tester, StackGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    for (var i = 0; i < 60 && !finished; i++) {
      await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑫ 플래피버드: 시작→낙하→충돌 종료', (tester) async {
    var finished = false;
    await mount(tester, FlappyGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    await tester.pump(const Duration(seconds: 8)); // 플랩 안 하면 낙하 충돌
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑬ 벽돌깨기: 진입 로드 OK + 시작/발사 동작', (tester) async {
    await mount(tester, BreakoutGame(onFinish: (_) {}));
    // 로드 버그 회귀 방지: 진입 즉시 시작 화면이 떠야 함
    expect(find.text('시작'), findsOneWidget);
    await tapStart(tester);
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false); // 공 발사
    await tester.pump(const Duration(seconds: 6));
    // 크래시 없이 진행(점수 표시 존재)
    expect(find.textContaining('🧱'), findsWidgets); // 로고만 표시
    await teardown(tester);
  });

  testWidgets('⑭ 버블슈터: 위쪽으로 발사 반복', (tester) async {
    await mount(tester, BubbleGame(onFinish: (s) {}));
    await tapStart(tester);
    for (var i = 0; i < 12; i++) {
      await tester.tapAt(const Offset(540, 200)); // 화면 윗부분으로 발사
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(find.textContaining('🫧'), findsWidgets); // 로고만 표시
    await teardown(tester);
  });

  testWidgets('⑮ 사과게임: 드래그 선택 + 2분 후 종료', (tester) async {
    var finished = false;
    await mount(tester, AppleGame(onFinish: (s) => finished = true));
    await tapStart(tester);
    // 보드를 가로질러 드래그(선택 동작 실행)
    final box = tester.getRect(find.byType(Stack).first);
    await tester.dragFrom(box.topLeft + const Offset(40, 80), const Offset(200, 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 122));
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑯ 다트 게임: 시작→10발 던지기 → 종료', (tester) async {
    var finished = false;
    await mount(tester, DartGame(onFinish: (s) => finished = true));
    await tester.tap(find.byType(GestureDetector).first); // 시작
    await tester.pump();
    // 10발 던지기(각 던지기 후 비행+장전 시간 경과)
    for (var i = 0; i < 12 && !finished; i++) {
      await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(finished, isTrue);
    await teardown(tester);
  });

  testWidgets('⑰ 아보카도 점프: 시작→좌우 조작 + 자동 점프 진행', (tester) async {
    await mount(tester, AvocadoGame(onFinish: (s) {}));
    await tapStart(tester);
    // 왼쪽을 길게 눌러 가로 이동(꾹 누르고 있는 조작) → 자동 점프 진행
    final left = tester.getCenter(find.byType(GestureDetector).first);
    final g = await tester.startGesture(left);
    await tester.pump(const Duration(seconds: 2));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    // 크래시 없이 진행(상단바에 점수 표시 존재)
    expect(find.textContaining('🥑'), findsWidgets);
    await teardown(tester);
  });
}
