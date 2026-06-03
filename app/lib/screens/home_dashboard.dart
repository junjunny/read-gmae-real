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
      // 오늘의 명언이 없으면 생성(자정 트리거 대용: 앱 실행 시 체크)
      _points.ensureTodayQuote().catchError((_) {});
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
          if (firebaseReady) ...[const SizedBox(height: 12), _quoteCard()],
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

  Widget _quoteCard() {
    final myId = SessionPrefs.userId ?? '0421';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _points.watchTodayQuote(),
      builder: (context, snap) {
        final data = snap.data;
        final text = (data?['text'] as String?)?.trim();
        final claimed = Map<String, dynamic>.from(data?['claimed'] ?? {});
        final mineDone = claimed[myId] == true;
        return Card(
          color: const Color(0xFFF3EFFF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✍️ 오늘의 명언', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (text == null || text.isEmpty)
                  const Text('오늘의 명언을 준비 중이에요... 🌙\n(메뉴 추천에서 Gemini 키를 등록하면 매일 떠요)',
                      style: TextStyle(fontSize: 13, color: Colors.grey))
                else ...[
                  Text('“$text”', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
                  const SizedBox(height: 12),
                  if (mineDone)
                    const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 6),
                      Text('오늘 필사 완료! (+50P)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ])
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _writeQuote(text),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('필사하고 +50P (띄어쓰기까지 정확히!)'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _writeQuote(String target) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✍️ 명언 필사'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF3EFFF), borderRadius: BorderRadius.circular(8)),
              child: Text(target, style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '위 문장을 똑같이 입력하세요', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            const Text('띄어쓰기·맞춤법까지 정확해야 +50P 인정돼요.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('제출')),
        ],
      ),
    );
    if (ok != true) return;
    final myId = SessionPrefs.userId ?? '0421';
    try {
      final res = await _points.claimQuote(myId, ctrl.text);
      if (!mounted) return;
      final msg = switch (res) {
        QuoteResult.ok => '정확해요! +50P 🎉',
        QuoteResult.already => '오늘은 이미 필사했어요 ✅',
        QuoteResult.mismatch => '아쉬워요! 띄어쓰기·맞춤법까지 정확히 다시 써봐요 ✍️',
        QuoteResult.noQuote => '아직 오늘의 명언이 없어요',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('채점 실패: $e')));
    }
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
