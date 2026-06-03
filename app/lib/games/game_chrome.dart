import 'package:flutter/material.dart';

/// 게임 화면에 현재 월드레코드(점수만) 값을 내려보내는 상속 위젯.
/// minigames_screen 에서 게임을 띄울 때 감싸준다.
class GameRecord extends InheritedWidget {
  final int? best;
  const GameRecord({super.key, required this.best, required super.child});

  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameRecord>()?.best;

  @override
  bool updateShouldNotify(GameRecord old) => old.best != best;
}

/// 게임 상단바 제목: 게임 이름 없이 [로고/점수/시간 등] 앞에 🏆월드레코드(점수만).
/// FittedBox 로 폭에 맞춰 줄여 모든 정보가 항상 보이게 한다.
class GameTitle extends StatelessWidget {
  /// 게임별 라이브 정보(로고 이모지 + 점수 + 시간 등). 게임 이름은 넣지 않는다.
  final String live;
  const GameTitle(this.live, {super.key});

  @override
  Widget build(BuildContext context) {
    final best = GameRecord.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        '🏆 ${best ?? '-'}    $live',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
