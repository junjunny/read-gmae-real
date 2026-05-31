import 'package:flutter/material.dart';

/// 메뉴 추천: 몇 가지 질문에 답하면 추천 결과를 보여준다.
/// (지금은 규칙 기반 추천. 추후 실제 AI API 연동 가능)
class MenuRecommendScreen extends StatefulWidget {
  const MenuRecommendScreen({super.key});
  @override
  State<MenuRecommendScreen> createState() => _MenuRecommendScreenState();
}

class _QA {
  final String q;
  final List<String> options;
  const _QA(this.q, this.options);
}

const _questions = <_QA>[
  _QA('지금 얼마나 배고파?', ['살짝', '보통', '엄청']),
  _QA('어떤 게 당겨?', ['뜨끈한 국물', '매콤한 거', '담백/건강식', '기름진 거']),
  _QA('분위기는?', ['집에서 편하게', '밖에서 데이트', '간단하게']),
  _QA('맵기는?', ['안 매움', '적당히', '아주 맵게']),
];

// 키워드 → 후보 메뉴
const Map<String, List<String>> _pool = {
  '국물': ['김치찌개', '순두부찌개', '우동', '쌀국수', '라멘', '칼국수', '설렁탕'],
  '매콤': ['떡볶이', '마라탕', '불닭', '낙지볶음', '닭갈비', '비빔냉면'],
  '담백': ['샐러드', '연어덮밥', '초밥', '월남쌈', '김밥', '비빔밥'],
  '기름': ['치킨', '피자', '햄버거', '돈까스', '족발', '곱창'],
};

class _MenuRecommendScreenState extends State<MenuRecommendScreen> {
  final List<int> _answers = List.filled(_questions.length, -1);
  String? _result;

  void _recommend() {
    // 2번 질문(당기는 것)으로 풀 선택 + 배고픔/맵기로 살짝 가중
    final craving = _answers[1];
    final key = ['국물', '매콤', '담백', '기름'][craving < 0 ? 0 : craving];
    var list = List<String>.from(_pool[key]!);
    // 간단한 가변 선택 (질문 답 조합으로 인덱스 결정 — 매번 같은 답이면 같은 결과)
    final seed = _answers.fold<int>(7, (a, b) => a * 31 + (b + 1));
    final pick = list[seed.abs() % list.length];
    setState(() => _result = pick);
  }

  @override
  Widget build(BuildContext context) {
    final answered = !_answers.contains(-1);
    return Scaffold(
      appBar: AppBar(title: const Text('메뉴 추천 🍽️')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _questions.length; i++) _buildQ(i),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: answered ? _recommend : null,
            icon: const Icon(Icons.auto_awesome),
            label: Text(answered ? '추천 받기' : '질문에 모두 답해주세요'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('오늘의 추천 메뉴는!', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('🍴 $_result', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _recommend, child: const Text('다른 거 추천')),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('※ 지금은 답변 기반 추천이에요. 추후 진짜 AI 추천으로 업그레이드 가능!',
              style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildQ(int i) {
    final qa = _questions[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q${i + 1}. ${qa.q}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (var j = 0; j < qa.options.length; j++)
                  ChoiceChip(
                    label: Text(qa.options[j]),
                    selected: _answers[i] == j,
                    onSelected: (_) => setState(() {
                      _answers[i] = j;
                      _result = null;
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
