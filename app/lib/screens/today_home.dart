import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/entry.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/session_prefs.dart';
import '../util/daily_topic.dart';
import '../util/users.dart';
import '../widgets/entry_image.dart';
import 'canvas_screen.dart';

/// 오늘 탭: 오늘의 주제 + 그리기 진입 + 오늘 제출 현황(나/상대).
class TodayHome extends StatefulWidget {
  const TodayHome({super.key});
  @override
  State<TodayHome> createState() => _TodayHomeState();
}

class _TodayHomeState extends State<TodayHome> {
  Uint8List? _profileBytes;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

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
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await SessionPrefs.setProfile(base64Encode(bytes));
      if (mounted) setState(() => _profileBytes = bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진 선택 실패: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    await SessionPrefs.clear();
    // authStateChanges가 로그인 화면으로 자동 전환
  }

  @override
  Widget build(BuildContext context) {
    final topic = topicForDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko').format(DateTime.now())),
        actions: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
            child: _profileBytes == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 6),
          Center(child: Text(nickOf(SessionPrefs.userId), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
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
          // 오늘의 주제 카드
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🎯 오늘의 주제', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(topic, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.brush),
                    label: const Text('이 주제로 그리기'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _openCanvas(context, topic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('💌 오늘의 그림', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (!firebaseReady)
            const _NoticeCard()
          else
            _TodayEntries(date: _today),
        ],
      ),
    );
  }

  void _openCanvas(BuildContext context, String topic) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CanvasScreen(
        topic: topic,
        onSubmit: firebaseReady
            ? (Uint8List png) async {
                await RoomService().submit(pngBytes: png, topic: topic, date: _today);
                return true;
              }
            : null,
      ),
    ));
  }
}

class _TodayEntries extends StatelessWidget {
  final String date;
  const _TodayEntries({required this.date});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: RoomService().watchByDate(date),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final items = snap.data!;
        if (items.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('아직 오늘 제출된 그림이 없어요.\n먼저 그려서 제출해보세요! ✏️', textAlign: TextAlign.center))));
        }
        return Column(
          children: items
              .map((e) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.4,
                          child: EntryImage(b64: e.imageB64),
                        ),
                        ListTile(
                          leading: const Icon(Icons.brush),
                          title: Text(e.author),
                          subtitle: Text(DateFormat('HH:mm').format(e.createdAt)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.cloud_off, color: Colors.amber),
            SizedBox(height: 8),
            Text('지금은 그리기·저장만 됩니다.\nFirebase를 연결하면 둘이 제출·공유·기록이 켜져요.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
