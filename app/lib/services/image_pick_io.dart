import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 모바일: 갤러리에서 사진을 골라 바이트로 반환(취소 시 null).
Future<Uint8List?> pickImageBytes() async {
  final f = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 400,
    maxHeight: 400,
    imageQuality: 80,
  );
  if (f == null) return null;
  return f.readAsBytes();
}
