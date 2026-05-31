import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_prefs.dart';

/// 로그인 게이트: 본인 ID(생일) + 비밀번호.
/// Firebase 인증 상태를 구독 → 로그인되면 child, 로그아웃되면 로그인 폼.
class LoginGate extends StatelessWidget {
  final Widget child;
  const LoginGate({super.key, required this.child});

  static const List<String> allowedIds = ['0421', '0118'];
  static const String roomId = '0516';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        final id = user?.email?.split('@').first;
        if (user != null && id != null && allowedIds.contains(id)) {
          SessionPrefs.userId = id;
          SessionPrefs.roomId = roomId;
          // 비차단 저장
          SessionPrefs.save(userId: id, roomId: roomId);
          return child;
        }
        return const _LoginForm();
      },
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _auth = AuthService();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (!LoginGate.allowedIds.contains(id)) {
      setState(() => _error = '등록되지 않은 ID예요. (본인 생일 4자리)');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.loginOrRegister(id, pw);
      // 성공 시 authStateChanges가 LoginGate를 자동 전환
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _msg(e.code));
    } catch (e) {
      setState(() => _error = '오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _msg(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return '비밀번호가 틀렸어요.';
      case 'weak-password':
        return '비밀번호가 너무 약해요 (6자 이상).';
      case 'operation-not-allowed':
        return '콘솔에서 이메일/비밀번호 로그인을 켜주세요.';
      case 'network-request-failed':
        return '네트워크 오류 — 연결을 확인해주세요.';
      default:
        return '로그인 실패 ($code)';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                TextField(
                  controller: _pwCtrl,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: '비밀번호 (6자 이상)',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('입장하기')),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('처음이면 입력한 비밀번호로 가입돼요.\n다음부터 같은 비밀번호로 로그인!',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
