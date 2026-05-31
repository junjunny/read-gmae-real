import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/points_service.dart';
import '../services/session_prefs.dart';
import '../util/dday.dart';
import 'drawing_today.dart';
import 'menu_recommend.dart';
import 'minigames_screen.dart';
import 'prize_screen.dart';

/// 홈: [주니 포인트 | D+ | 히수 포인트] 헤더 + 4개 카테고리 카드.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _points = PointsService();
  Uint8List? _profileBytes;

  @override
  void initState() {
    super.initState();
    final b64 = SessionPrefs.profileB64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        _profileBytes = base64Decode(b64);
      } catch (_) {}
    }
  }

  Future<void> _pickProfile() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 80);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      await SessionPrefs.setProfile(base64Encode(bytes));
      if (mounted) setState(() => _profileBytes = bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진 선택 실패: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    await SessionPrefs.clear();
  }

  void _go(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JHS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
            child: _profileBytes == null ? const Icon(Icons.person, size: 16) : null,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'profile') _pickProfile();
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.image, size: 18), SizedBox(width: 8), Text('프로필 사진 변경')])),
              PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('로그아웃')])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _cat('오늘의 그림', '🎨', Colors.pink.shade50, () => _go(const DrawingTodayScreen())),
              _cat('메뉴 추천', '🍽️', Colors.orange.shade50, () => _go(const MenuRecommendScreen())),
              _cat('미니게임', '🎮', Colors.blue.shade50, () => _go(const MiniGamesScreen())),
              _cat('상품 현황', '🎁', Colors.green.shade50, () => _go(const PrizeScreen())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: firebaseReady
            ? StreamBuilder<Map<String, int>>(
                stream: _points.watchPoints(),
                builder: (context, snap) {
                  final p = snap.data ?? {'0421': 0, '0118': 0};
                  return _headerRow(p['0421'] ?? 0, p['0118'] ?? 0);
                },
              )
            : _headerRow(0, 0),
      ),
    );
  }

  Widget _headerRow(int juni, int hisu) {
    return Row(
      children: [
        Expanded(child: _ptColumn('주니', juni)),
        Column(
          children: [
            Text(dPlusLabel(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF6F91))),
            const Text('우리가 만난 지', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Expanded(child: _ptColumn('히수', hisu)),
      ],
    );
  }

  Widget _ptColumn(String name, int pt) => Column(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('$pt P', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _cat(String title, String emoji, Color bg, VoidCallback onTap) {
    return Card(
      color: bg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
