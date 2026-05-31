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
  _QA('지금 얼마나 배고파?', ['살짝', '보통', '엄청']),
  _QA('어떤 게 당겨?', ['뜨끈한 국물', '매콤한 거', '담백/건강식', '기름진 거', '아무거나']),
  _QA('상황은?', ['집에서 배달', '밖에서 외식', '간단하게', '야식']),
  _QA('맵기는?', ['안 매움', '적당히', '아주 맵게']),
];

class _MenuRecommendScreenState extends State<MenuRecommendScreen> {
  final List<int> _answers = List.filled(_questions.length, -1);
  bool _loading = false;
  String? _result;
  String? _error;

  final _points = PointsService();
  final _keyCtrl = TextEditingController();
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
      final a = [
        _questions[0].options[_answers[0]],
        _questions[1].options[_answers[1]],
        _questions[2].options[_answers[2]],
        _questions[3].options[_answers[3]],
      ];
      final prompt = '''너는 커플을 위한 메뉴 추천 도우미야. 아래 조건으로 딱 하나의 메뉴를 추천해줘.
- 배고픔: ${a[0]}
- 당기는 것: ${a[1]}
- 상황: ${a[2]}
- 맵기: ${a[3]}
한국에서 배달/외식 가능한 현실적인 메뉴로.
출력은 정확히 이 형식 한 줄로만: "🍴 메뉴이름 — 추천 이유(25자 이내, 친근하게)"''';
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
