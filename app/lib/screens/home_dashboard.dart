import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/points_service.dart';
import '../services/push_service.dart';
import '../services/session_prefs.dart';
import '../util/dday.dart';
import '../util/users.dart';
import 'drawing_today.dart';
import 'menu_recommend.dart';
import 'minigames_screen.dart';
import 'prize_screen.dart';

/// 홈: [주니(왼) | 💙+ | 히수(오)] 헤더(프로필+이름+포인트) + 4개 카테고리.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _points = PointsService();

  @override
  void initState() {
    super.initState();
    // 앱 열릴 때 지난 날짜(자정 경과분) 자동 정산
    if (firebaseReady) {
      _points.settlePending().catchError((_) {});
    }
  }

  Future<void> _pickProfile() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 75);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final b64 = base64Encode(bytes);
      await SessionPrefs.setProfile(b64); // 로컬
      if (firebaseReady) await _points.setProfile(SessionPrefs.userId ?? '0421', b64); // 공유
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 사진을 바꿨어요 📸')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진 선택 실패: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    await SessionPrefs.clear();
  }

  void _go(Widget s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  Future<void> _enablePush() async {
    final msg = await PushService.enable();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg == 'ok' ? '알림이 켜졌어요! 🔔' : msg), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _poke() async {
    final myId = SessionPrefs.userId ?? '0421';
    final toId = myId == '0421' ? '0118' : '0421';
    final ctrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('💗 ${nickOf(toId)}에게 콕 찌르기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, autofocus: true, maxLength: 50, decoration: const InputDecoration(hintText: '예: 얼른 그림 그려! 🎨', border: OutlineInputBorder())),
            const Text('상대 알림으로 전송돼요 (무료 방식이라 ~10분 내 도착)', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('보내기')),
        ],
      ),
    );
    if (send == true) {
      final text = ctrl.text.trim().isEmpty ? '콕! 👈' : ctrl.text.trim();
      try {
        await PointsService().sendPoke(myId, toId, text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('콕! 보냈어요 💗 (~10분 내 도착)')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
      }
    }
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JHS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) {
              if (v == 'profile') _pickProfile();
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.image, size: 18), SizedBox(width: 8), Text('내 프로필 사진 변경')])),
              PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('로그아웃')])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          if (firebaseReady) _settleBanner(),
          const SizedBox(height: 12),
          if (firebaseReady)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enablePush,
                    icon: const Icon(Icons.notifications_active, size: 18),
                    label: const Text('알림 켜기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _poke,
                    icon: const Icon(Icons.touch_app, size: 18),
                    label: const Text('콕 찌르기'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: firebaseReady
            ? StreamBuilder<Map<String, int>>(
                stream: _points.watchPoints(),
                builder: (context, pSnap) {
                  final pts = pSnap.data ?? {'0421': 0, '0118': 0};
                  return StreamBuilder<Map<String, String?>>(
                    stream: _points.watchProfiles(),
                    builder: (context, prSnap) {
                      final pr = prSnap.data ?? {};
                      return _headerRow(pts['0421'] ?? 0, pts['0118'] ?? 0, _decode(pr['0421']), _decode(pr['0118']));
                    },
                  );
                },
              )
            : _headerRow(0, 0, _decode(SessionPrefs.profileB64), null),
      ),
    );
  }

  Widget _headerRow(int juni, int hisu, Uint8List? juniPic, Uint8List? hisuPic) {
    return Row(
      children: [
        Expanded(child: _person('주니', juni, juniPic)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dPlusLabel(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF42A5F5))),
            const Text('우리가 만난 지', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Expanded(child: _person('히수', hisu, hisuPic)),
      ],
    );
  }

  Widget _person(String name, int pt, Uint8List? pic) => Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFFFE0EC),
            backgroundImage: pic != null ? MemoryImage(pic) : null,
            child: pic == null ? const Icon(Icons.person, size: 26) : null,
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('$pt P', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _settleBanner() {
    return StreamBuilder<String?>(
      stream: _points.watchLastSummary(),
      builder: (context, snap) {
        final s = snap.data;
        if (s == null || s.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('지난 정산 결과\n$s', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
