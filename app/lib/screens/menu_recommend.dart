import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/gemini_service.dart';
import '../services/points_service.dart';

/// 메뉴 추천: 아주 세세한 질문에 답하면 Gemini가 진짜 참고가 되는
/// 구조화된 추천(메인+대안+가격+어디서/어떻게+페어링+꿀팁+식단/주의)을 준다.
class MenuRecommendScreen extends StatefulWidget {
  const MenuRecommendScreen({super.key});
  @override
  State<MenuRecommendScreen> createState() => _MenuRecommendScreenState();
}

class _QA {
  final String key; // 프롬프트에 쓰는 라벨
  final String q;
  final List<String> options;
  final bool multi; // 다중 선택
  final bool req; // 필수 응답
  const _QA(this.key, this.q, this.options, {this.multi = false, this.req = true});
}

const _questions = <_QA>[
  _QA('누구와', '누구랑 먹어?', ['혼자', '연인(데이트)', '친구', '가족', '직장/동료', '모임/여럿']),
  _QA('인원', '총 몇 명?', ['1명', '2명', '3~4명', '5명 이상']),
  _QA('방식', '어떻게 먹을까?', ['배달', '외식(나가서)', '직접 요리', '포장/픽업', '밀키트', '편의점/간편식']),
  _QA('시간대', '시간대는?', ['아침', '브런치', '점심', '저녁', '야식', '간식/디저트']),
  _QA('예산', '1인 예산은?', ['~7천원', '~1.2만원', '~2만원', '~3만원', '3만원+']),
  _QA('배고픔', '지금 배고픔은?', ['살짝', '보통', '많이', '폭발 직전']),
  _QA('양', '원하는 양은?', ['가볍게', '적당히', '푸짐하게']),
  _QA('장르', '끌리는 장르 (여러 개 가능)', [
    '한식', '중식', '일식', '양식', '분식', '아시안(태국·베트남)', '멕시칸',
    '패스트푸드', '고기/구이', '면/국물', '해산물', '치킨', '디저트/카페', '아무거나'
  ], multi: true),
  _QA('맵기', '맵기는?', ['안 매움', '약간', '보통', '맵게', '아주 맵게']),
  _QA('온도', '온도/스타일?', ['뜨끈한 국물', '따뜻한', '시원한/찬', '상관없음']),
  _QA('상황', '상황/기분은?', [
    '평범한 끼니', '데이트', '야식', '해장', '기념일', '스트레스 해소', '가볍게', '든든하게', '입맛 없음'
  ]),
  _QA('식단목표', '식단 목표는?', ['상관없음', '다이어트(저칼로리)', '단백질/벌크업', '건강식', '든든·고칼로리']),
  _QA('조리시간', '조리/대기 시간 여유?', ['10분 내 빨리', '30분 정도', '여유 있음']),
  _QA('날씨', '오늘 날씨는? (선택)', ['덥고 습함', '춥고 쌀쌀', '비/눈', '선선/평범'], req: false),
  _QA('술음료', '술/음료 곁들임? (선택)', [
    '생각 없음', '소주', '맥주', '와인', '막걸리', '하이볼', '무알콜/탄산', '커피/차'
  ], req: false),
  _QA('제한', '식이 제한 (여러 개 가능, 선택)', [
    '없음', '채식/비건', '글루텐프리', '유당 불가', '해산물 알레르기', '견과류 알레르기', '돼지고기 X', '소고기 X'
  ], multi: true, req: false),
];

class _MenuRecommendScreenState extends State<MenuRecommendScreen> {
  // 각 질문의 선택(단일=원소 1개, 다중=여러 개)
  final List<Set<int>> _ans = List.generate(_questions.length, (_) => <int>{});
  bool _loading = false;
  String? _result;
  String? _error;

  final _points = PointsService();
  final _keyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(); // 지역/동네
  final _avoidCtrl = TextEditingController(); // 싫어하는/못 먹는 재료
  final _recentCtrl = TextEditingController(); // 최근 먹은 것
  final _extraCtrl = TextEditingController(); // 그 외 자유 요청
  bool _checkingKey = true;
  bool _hasKey = false;
  bool _savingKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _locationCtrl.dispose();
    _avoidCtrl.dispose();
    _recentCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
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

  bool get _answered {
    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i].req && _ans[i].isEmpty) return false;
    }
    return true;
  }

  String _selectedText(int i) => _ans[i].map((j) => _questions[i].options[j]).join(', ');

  Future<void> _recommend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qa = [
        for (var i = 0; i < _questions.length; i++)
          if (_ans[i].isNotEmpty) '- ${_questions[i].key}: ${_selectedText(i)}'
      ].join('\n');

      final method = _ans[2].isNotEmpty ? _questions[2].options[_ans[2].first] : '외식';
      final location = _locationCtrl.text.trim();
      final avoid = _avoidCtrl.text.trim();
      final recent = _recentCtrl.text.trim();
      final extra = _extraCtrl.text.trim();

      final extras = [
        if (location.isNotEmpty) '- 지역/동네: $location',
        if (avoid.isNotEmpty) '- 싫어함/못 먹는 재료(반드시 제외): $avoid',
        if (recent.isNotEmpty) '- 최근 먹은 것(중복 회피): $recent',
        if (extra.isNotEmpty) '- 추가 요청: $extra',
      ].join('\n');

      final prompt = '''너는 한국 실정에 빠삭한 음식 메뉴 컨설턴트야. 아래 사람의 조건을 "전부" 정밀하게 반영해서, 지금 바로 실행 가능한 추천을 해줘. 두루뭉술하지 말고 구체적이고 현실적으로.

[사용자 조건]
$qa
${extras.isEmpty ? '' : '\n[추가 정보]\n$extras'}

[반드시 지킬 규칙]
1. "$method" 방식으로 실제 가능한 메뉴만. 배달이면 한국에서 진짜 배달되는 것만(샤브샤브·오마카세·뷔페 등 배달 어려운 건 배달일 때 제외). 직접요리면 난이도와 조리시간을 조리 여유에 맞춰. 편의점/간편식이면 실제 편의점·마트에서 살 수 있는 제품류로.
2. 인원·예산·양·배고픔을 숫자로 현실적으로 맞춰(가격은 한국 2024~2025 시세 기준 대략값).
3. 맵기·온도·식단 목표·식이 제한·알레르기·싫어하는 재료를 절대 위반하지 마. 제한이 있으면 그걸 지키는 선에서 골라.
4. 상황/기분/시간대/날씨에 어울리게(예: 비 오면 전·국물, 더우면 시원한 것, 해장이면 속 풀리는 것, 데이트면 분위기).
5. 최근 먹은 것과 겹치지 말고, 뻔한 치킨·피자 반복 금지. 센스 있게, 가끔 구체적 메뉴명/프랜차이즈/가게 유형까지.
6. 지역이 있으면 그 동네에서 현실적으로(배달앱 카테고리나 가게 유형 수준으로). 없는 가게명·전화번호·URL을 지어내지 마.

[출력 형식] 아래 틀을 "그대로" 써. 마크다운(#, **) 쓰지 말고 이모지 줄로. 한국어로, 친근하지만 정확하게.

🍽️ 추천: (메뉴 이름 — 필요하면 구체적으로)
💬 이유: (이 조건들에 왜 딱인지 2~3줄, 조건을 실제로 엮어서)
💰 예상 비용: (1인 약 X원 / 총 Y원, 인원 반영)
📍 어디서·어떻게: ($method 기준 구체적으로 — 배달앱 카테고리/프랜차이즈 후보/가게 유형, 직접요리면 핵심 재료와 조리 N분, 편의점이면 제품 조합)
🍴 곁들임/페어링: (사이드·음료${_ans[14].isNotEmpty ? '·술' : ''} 추천)
👩‍🍳 주문·조리 꿀팁: (실전 팁 1~2개 — 옵션 선택, 소스, 익힘 정도 등)

🔁 대안 2가지:
2) (메뉴) — (한 줄 이유) · 약 X원
3) (메뉴) — (한 줄 이유) · 약 X원

🥗 식단 코멘트: (식단 목표가 '상관없음'이 아니면 칼로리/단백질 등 한 줄, 아니면 "—")
⚠️ 참고/주의: (맵기·알레르기·제한·최근 먹은 것 반영해서 무엇을 피했는지 한 줄)''';

      final res = await GeminiService.generate(prompt, model: 'gemini-flash-latest');
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = '추천 실패: $e\n(잠시 후 다시 시도해주세요)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAll() {
    setState(() {
      for (final s in _ans) {
        s.clear();
      }
      _locationCtrl.clear();
      _avoidCtrl.clear();
      _recentCtrl.clear();
      _extraCtrl.clear();
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingKey) {
      return Scaffold(appBar: AppBar(title: const Text('메뉴 추천 🍽️')), body: const Center(child: CircularProgressIndicator()));
    }
    if (!_hasKey) return _keyGate();

    final answered = _answered;
    final answeredReq = _questions.asMap().entries.where((e) => e.value.req && _ans[e.key].isNotEmpty).length;
    final totalReq = _questions.where((q) => q.req).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('메뉴 추천 🍽️'),
        actions: [IconButton(onPressed: _resetAll, icon: const Icon(Icons.refresh), tooltip: '처음부터')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('🔎 더 자세히 답할수록 추천이 정확해져요. (필수 $answeredReq/$totalReq)\n선택 항목·자유 입력까지 채우면 진짜 참고가 되는 답이 나와요.',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _questions.length; i++) _buildQ(i),
          _textCard('📍 지역/동네 (선택)', _locationCtrl, '예: 서울 강남, 부산 서면 — 배달·맛집 현실 반영'),
          _textCard('🚫 싫어함/못 먹는 재료 (선택)', _avoidCtrl, '예: 오이, 고수, 내장, 회 빼고'),
          _textCard('🕘 최근 먹은 것 (선택)', _recentCtrl, '예: 어제 치킨, 점심 김치찌개 — 중복 회피'),
          _textCard('✍️ 그 외 요청 (선택)', _extraCtrl, '예: 단백질 많이, 혼술 안주, 디저트까지'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (answered && !_loading) ? _recommend : null,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? 'AI가 정밀 분석 중...' : (answered ? 'AI 정밀 추천 받기' : '필수 질문에 모두 답해주세요')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Text('✨ Gemini 정밀 추천', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const SizedBox(height: 12),
                    SelectableText(_result!, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _loading ? null : _recommend,
                        icon: const Icon(Icons.casino, size: 18),
                        label: const Text('다른 추천'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('⚡ gemini-flash (정밀 모드)', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _textCard(String label, TextEditingController ctrl, String hint) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
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
            Row(
              children: [
                Expanded(child: Text('Q${i + 1}. ${qa.q}', style: const TextStyle(fontWeight: FontWeight.bold))),
                if (!qa.req) const Text('선택', style: TextStyle(fontSize: 11, color: Colors.grey)),
                if (qa.multi) const Padding(padding: EdgeInsets.only(left: 6), child: Text('다중', style: TextStyle(fontSize: 11, color: Color(0xFFFF6F91)))),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                for (var j = 0; j < qa.options.length; j++)
                  ChoiceChip(
                    label: Text(qa.options[j]),
                    selected: _ans[i].contains(j),
                    onSelected: (_) => setState(() {
                      if (qa.multi) {
                        _ans[i].contains(j) ? _ans[i].remove(j) : _ans[i].add(j);
                      } else {
                        _ans[i]
                          ..clear()
                          ..add(j);
                      }
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
