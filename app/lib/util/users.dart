/// 고정 사용자 정보. ID(생일) → 닉네임.
/// 사용자가 늘어나면 여기에 추가.
const Map<String, String> kNicknames = {
  '0421': '주니',
  '0118': '히수',
};

String nickOf(String? id) => kNicknames[id] ?? (id ?? '익명');
