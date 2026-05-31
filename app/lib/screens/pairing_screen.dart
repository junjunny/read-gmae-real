import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_session.dart';
import '../services/couple_service.dart';
import 'home_shell.dart';

/// 커플 연결 화면: 코드 생성(초대) 또는 코드 입력(합류).
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _couple = CoupleService();
  final _codeInput = TextEditingController();
  String? _myCode;
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final code = await _couple.createCouple(AppSession.instance.uid!);
      setState(() => _myCode = code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _couple.joinByCode(AppSession.instance.uid!, _codeInput.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } catch (e) {
      setState(() => _error = '$e'.replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상대와 연결하기')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('💑 둘 중 한 명만 코드를 만들고, 상대는 그 코드를 입력하면 연결돼요.'),
            const SizedBox(height: 24),
            // --- 코드 만들기 ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('① 내가 초대하기'),
                    const SizedBox(height: 8),
                    if (_myCode == null)
                      FilledButton(onPressed: _busy ? null : _create, child: const Text('초대 코드 생성'))
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SelectableText(_myCode!,
                              style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => Clipboard.setData(ClipboardData(text: _myCode!)),
                          ),
                        ],
                      ),
                    if (_myCode != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('상대가 이 코드를 입력하면 연결됩니다. 연결되면 자동으로 시작돼요.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- 코드 입력 ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('② 코드로 합류하기'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeInput,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: '6자리 코드 입력',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _busy ? null : _join, child: const Text('연결하기')),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
