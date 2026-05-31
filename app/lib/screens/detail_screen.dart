import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../models/drawing.dart';
import '../services/image_export.dart';

/// 그림 상세: 풀스크린 + 다운로드(웹: 파일 다운로드 / 모바일: 사진첩).
class DetailScreen extends StatelessWidget {
  final Drawing drawing;
  const DetailScreen({super.key, required this.drawing});

  Future<void> _download(BuildContext context) async {
    final res = await http.get(Uri.parse(drawing.imageUrl));
    final ok = await saveImageBytes(res.bodyBytes, 'grimpingpong_${drawing.id}.png');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '이미지를 저장했어요 🎉' : '저장 실패')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(drawing.topic),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: () => _download(context)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(imageUrl: drawing.imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${drawing.authorName} · ${DateFormat('yyyy년 M월 d일 HH:mm').format(drawing.createdAt)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
