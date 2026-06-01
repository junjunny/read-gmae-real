import 'package:flutter/material.dart';

/// 미니게임 공통 그래픽 헬퍼(시각 전용 — 게임 로직/수치에는 영향 없음).

/// 부드러운 세로 그라데이션 배경.
BoxDecoration bgGradient(List<Color> colors) => BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
    );

// 자주 쓰는 배경 팔레트
const List<Color> kBgLight = [Color(0xFFF7FAFF), Color(0xFFE6EEFB)];
const List<Color> kBgDark = [Color(0xFF1E2F4A), Color(0xFF0C1626)];

/// 둥근 모서리 + 입체 그라데이션 + 옅은 그림자 타일 데코.
Decoration tileDeco(Color base, {double radius = 8}) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, Colors.white, 0.28)!,
          base,
          Color.lerp(base, Colors.black, 0.14)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 1))],
    );

/// 광택 있는 원형(공/버블 등) 데코.
Decoration glossyCircle(Color base) => BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [Color.lerp(base, Colors.white, 0.65)!, base, Color.lerp(base, Colors.black, 0.2)!],
        stops: const [0.0, 0.55, 1.0],
      ),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
    );

/// 시작/게임오버용 둥근 패널 — 살짝 통통 떠오르는 등장 애니메이션.
class PopPanel extends StatelessWidget {
  final Widget child;
  const PopPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, s, c) => Opacity(opacity: s.clamp(0.0, 1.0), child: Transform.scale(scale: s, child: c)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: child,
      ),
    );
  }
}
