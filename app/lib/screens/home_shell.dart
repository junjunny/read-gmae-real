import 'package:flutter/material.dart';

import 'canvas_screen.dart';
import 'gallery_screen.dart';
import 'today_screen.dart';

/// 하단 3탭 셸. (오늘 / 그리기 / 히스토리)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const CanvasScreen(),
      const GalleryScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: '오늘'),
          NavigationDestination(icon: Icon(Icons.brush), label: '그리기'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: '히스토리'),
        ],
      ),
    );
  }
}
