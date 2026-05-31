import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/session_prefs.dart';

/// 탭하면 갤러리에서 프로필 이미지를 고르는 원형 아바타.
/// 선택한 이미지는 base64로 로컬에 저장된다.
class ProfileAvatar extends StatefulWidget {
  final double radius;
  const ProfileAvatar({super.key, this.radius = 18});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    final b64 = SessionPrefs.profileB64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        _bytes = base64Decode(b64);
      } catch (_) {}
    }
  }

  Future<void> _pick() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await SessionPrefs.setProfile(base64Encode(bytes));
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pick,
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
            child: _bytes == null ? Icon(Icons.person, size: widget.radius) : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.edit, size: 10),
            ),
          ),
        ],
      ),
    );
  }
}
