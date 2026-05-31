import 'package:flutter/material.dart';

import '../services/session_prefs.dart';

/// 로그인 게이트: 본인 ID(생일) + 초대코드.
/// - 본인 ID로 누가 접속했는지 구분 (포인트 적립 기준)
/// - 초대코드(같은 값)로 같은 방에 연결
class LoginGate extends StatefulWidget {
  final Widget child;
  const LoginGate({super.key, required this.child});

  /// 허용된 사용자 ID (생일). 필요시 여기만 늘리면 됨.
  static const List<String> allowedIds = ['0421', '0118'];

  /// 공유방 초대코드.
  static const String inviteCode = '0516';

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  final _idCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = true;
  bool _ok = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final id = SessionPrefs.userId;
    final room = SessionPrefs.roomId;
    _ok = id != null && LoginGate.allowedIds.contains(id) && room == LoginGate.inviteCode;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (!LoginGate.allowedIds.contains(id)) {
      setState(() => _error = '등록되지 않은 ID예요. (본인 생일 4자리)');
      return;
    }
    if (code != LoginGate.inviteCode) {
      setState(() => _error = '초대코드가 올바르지 않아요.');
      return;
    }
    await SessionPrefs.save(userId: id, roomId: code);
    if (mounted) setState(() => _ok = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ok) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎨', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 6),
                Text('JHS', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // 본인 ID
                TextField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: '본인 ID (생일 4자리)',
                    hintText: '예: 0421',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 12),
                // 초대코드
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: '초대코드',
                    hintText: '둘만의 코드',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('입장하기')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
