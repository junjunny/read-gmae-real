import 'dart:convert';

import 'package:http/http.dart' as http;

/// 제미나이(Gemini) 호출. 키는 코드에 넣지 않고 런타임에 Firestore에서 받아 설정.
/// (공개 레포에 키를 커밋하지 않기 위함 — 키는 비공개 Firestore에만 저장)
class GeminiService {
  static String? apiKey; // 앱 시작/메뉴 진입 시 Firestore에서 로드
  static const String _model = 'gemini-flash-lite-latest'; // 가장 빠른 경량 모델

  static bool get hasKey => apiKey != null && apiKey!.isNotEmpty;

  static Future<String> generate(String prompt) async {
    if (!hasKey) throw Exception('API 키가 설정되지 않았어요.');
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Gemini ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cands = data['candidates'] as List?;
    if (cands == null || cands.isEmpty) return '(추천 결과를 못 받았어요)';
    final parts = (cands[0]['content']?['parts']) as List?;
    final text = (parts != null && parts.isNotEmpty) ? parts[0]['text'] as String? : null;
    return (text ?? '(응답 없음)').trim();
  }
}
