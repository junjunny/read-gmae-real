import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Firestore에 저장된 base64 PNG를 표시.
class EntryImage extends StatelessWidget {
  final String b64;
  final BoxFit fit;
  const EntryImage({super.key, required this.b64, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {}
    if (bytes == null) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
    return Image.memory(bytes, fit: fit, gaplessPlayback: true);
  }
}
