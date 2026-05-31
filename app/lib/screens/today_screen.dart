import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/drawing.dart';
import '../services/drawing_service.dart';
import 'canvas_screen.dart';

/// 오늘 탭: 오늘의 주제 + 상대가 보낸 최신 그림.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final service = DrawingService();
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('M월 d일 (E)', 'ko').format(DateTime.now()))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 오늘의 주제
          StreamBuilder<String?>(
            stream: service.watchTodayTopic(_today),
            builder: (context, snap) {
              final topic = snap.data ?? '오늘의 주제를 기다리는 중...';
              return Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('🎯 오늘의 주제', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(topic, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.brush),
                        label: const Text('이 주제로 그리기'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CanvasScreen(topic: topic)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('💌 상대가 보낸 그림', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<Drawing?>(
            stream: service.watchPartnerLatest(),
            builder: (context, snap) {
              final d = snap.data;
              if (d == null) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('아직 받은 그림이 없어요 🥲')),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: d.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    ListTile(
                      title: Text(d.topic),
                      subtitle: Text('${d.authorName} · ${DateFormat('M월 d일 HH:mm').format(d.createdAt)}'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
