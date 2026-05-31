import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/gemini_service.dart';
import '../services/points_service.dart';

/// 메뉴 추천: 질문에 답하면 Gemini(가장 빠른 flash-lite)가 메뉴를 추천.
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
  _QA('누구랑 먹어?', ['혼자', '둘이', '여럿']),
  _QA('어떻게 먹을까?', ['배달', '외식(나가서)', '직접 요리', '포장/픽업']),
  _QA('1인 예산은?', ['~7천원', '~1.2만원', '~2만원', '2만원+']),
  _QA('지금 배고픔은?', ['살짝', '보통', '많이']),
  _QA('끌리는 종류?', ['한식', '중식', '일식', '양식', '분식', '아시안', '패스트푸드', '디저트/카페', '아무거나']),
  _QA('맵기는?', ['안 매움', '약간', '보통', '아주 맵게']),
  _QA('상황/기분은?', ['평범한 끼니', '데이트', '야식', '해장', '기념일', '스트레스 해소', '가볍게']),
  _QA('식단 고려?', ['상관없음', '다이어트', '든든하게', '건강하게']),
];

class _MenuRecommendScreenState extends State<MenuRecommendScreen> {
  final List<int> _answers = List.filled(_questions.length, -1);
  bool _loading = false;
  String? _result;
  String? _error;

  final _points = PointsService();
  final _keyCtrl = TextEditingController();
  final _avoidCtrl = TextEditingController(); // 피하고 싶은 것/최근 먹은 것
  bool _checkingKey = true;
  bool _hasKey = false;
  bool _savingKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    if (!firebaseReady) {
      setState(() {
        _checkingKey = false;
        _hasKey = false;
      });
      return;
    }
    try {
      final k = GeminiService.apiKey ?? await _points.getGeminiKey();
      GeminiService.apiKey = k;
      setState(() {
        _hasKey = GeminiService.hasKey;
        _checkingKey = false;
      });
    } catch (_) {
      setState(() => _checkingKey = false);
    }
  }

  Future<void> _saveKey() async {
    final k = _keyCtrl.text.trim();
    if (k.isEmpty) return;
    setState(() => _savingKey = true);
    try {
      await _points.setGeminiKey(k);
      GeminiService.apiKey = k;
      setState(() => _hasKey = true);
    } catch (e) {
      setState(() => _error = '키 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _savingKey = false);
    }
  }

  Future<void> _recommend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qa = [
        for (var i = 0; i < _questions.length; i++) '- ${_questions[i].q.replaceAll('?', '')}: ${_questions[i].options[_answers[i]]}'
      ].join('\n');
      final avoid = _avoidCtrl.text.trim();
      final method = _questions[1].options[_answers[1]];
      final prompt = '''너는 한국 음식 메뉴 추천 전문가야. 아래 조건을 모두 반영해서 **메뉴 딱 하나**를 현실적으로 추천해줘.

[조건]
$qa
${avoid.isEmpty ? '' : '- 피하고 싶은 것/최근 먹은 것: $avoid (이건 추천에서 제외)'}

[반드시 지킬 규칙]
1. "$method" 방식으로 실제 가능한 메뉴만 추천해. 특히 **배달이면 한국에서 진짜 배달되는 메뉴**만 (예: 샤브샤브·오마카세·뷔페·일부 횟집 등은 배달이 거의 안 되니 배달일 땐 제외).
2. 예산과 인원, 맵기, 식단 고려를 현실적으로 맞춰.
3. 상황/기분에 어울리게.
4. 너무 뻔한 것(치킨/피자)만 반복하지 말고 센스있게, 가끔 구체적 메뉴명으로.

[출력 형식] 정확히 아래 3줄로만:
🍴 메뉴: (메뉴 이름)
💡 이유: (왜 이게 딱인지 30자 이내, 친근하게)
🏠 팁: (어디서/어떻게 먹으면 좋은지 25자 이내)''';
      final res = await GeminiService.generate(prompt);
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = '추천 실패: $e\n(잠시 후 다시 시도해주세요)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingKey) {
      return Scaffold(appBar: AppBar(title: const Text('메뉴 추천 🍽️')), body: const Center(child: CircularProgressIndicator()));
    }
    if (!_hasKey) return _keyGate();

    final answered = !_answers.contains(-1);
    return Scaffold(
      appBar: AppBar(title: const Text('메뉴 추천 🍽️')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _questions.length; i++) _buildQ(i),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('피하고 싶은 것 / 최근 먹은 것 (선택)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _avoidCtrl,
                    decoration: const InputDecoration(hintText: '예: 어제 치킨 먹음, 오이 싫어, 회 빼고', border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (answered && !_loading) ? _recommend : null,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? 'AI가 고르는 중...' : (answered ? 'AI 추천 받기' : '질문에 모두 답해주세요')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('✨ Gemini 추천', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(_result!, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loading ? null : _recommend, child: const Text('다른 거 추천')),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('⚡ gemini-flash-lite (가장 빠른 모델)', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _keyGate() {
    return Scaffold(
      appBar: AppBar(title: const Text('메뉴 추천 🍽️')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('🤖 Gemini API 키 한 번만 등록하면\nAI 메뉴 추천이 켜져요.', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('키는 우리 비공개 DB에만 저장되고, 코드/공개 레포엔 안 들어갑니다.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(labelText: 'Gemini API 키', hintText: 'AIza... 또는 AQ...', border: OutlineInputBorder()),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _savingKey ? null : _saveKey,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _savingKey ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('등록하고 시작'),
          ),
          const SizedBox(height: 12),
          const Text('키 발급: https://aistudio.google.com/apikey', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
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
